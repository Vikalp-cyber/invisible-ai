import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../domain/models/chat_message.dart';
import '../../domain/models/cursor_runtime_config.dart';
import '../../domain/repositories/ai_provider_interface.dart';
import 'cursor_exceptions.dart';

/// Interview chat via [Cursor Cloud Agents API](https://cursor.com/docs/cloud-agent/api/endpoints).
///
/// Uses a durable no-repo cloud agent per chat session; follow-up messages reuse
/// the same agent so conversation context is preserved server-side.
class CursorProvider implements AIProvider {
  CursorProvider({http.Client? httpClient}) : _httpClient = httpClient;

  static const _baseUrl = 'https://api.cursor.com';

  final http.Client? _httpClient;
  http.Client? _activeClient;
  String? _agentId;
  bool _cancelled = false;

  @override
  AIProviderType get type => AIProviderType.cursor;

  @override
  bool get requiresApiKey => true;

  /// Clears the in-memory agent so the next message starts a fresh cloud agent.
  void resetSession() {
    _agentId = null;
  }

  @override
  Stream<StreamResponse> generateStream(
    List<ChatMessage> history,
    String prompt, {
    String? apiKey,
    Uint8List? imageBytes,
    String? providerModelId,
  }) async* {
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API key is required for Cursor.');
    }
    if (imageBytes != null) {
      throw Exception('Cursor cloud agents do not support image uploads in Flowdesk yet.');
    }

    _cancelled = false;
    _activeClient = _httpClient ?? http.Client();

    final modelId = (providerModelId == null || providerModelId.trim().isEmpty)
        ? CursorModelIds.defaultChat
        : providerModelId.trim();

    final runInfo = await _startRun(
      apiKey: apiKey,
      prompt: _buildPrompt(history, prompt),
      modelId: modelId,
    );

    yield* _streamRun(
      apiKey: apiKey,
      agentId: runInfo.agentId,
      runId: runInfo.runId,
    );
  }

  String _buildPrompt(List<ChatMessage> history, String prompt) {
    final buffer = StringBuffer();
    for (final msg in history) {
      if (msg.content.trim().isEmpty) {
        continue;
      }
      final role = msg.role == MessageRole.user ? 'User' : 'Assistant';
      buffer.writeln('$role: ${msg.content.trim()}');
    }
    buffer.writeln('User: ${prompt.trim()}');
    return buffer.toString().trim();
  }

  Future<({String agentId, String runId})> _startRun({
    required String apiKey,
    required String prompt,
    required String modelId,
  }) async {
    if (_agentId != null) {
      try {
        return await _createFollowUpRun(
          apiKey: apiKey,
          agentId: _agentId!,
          prompt: prompt,
          modelId: modelId,
        );
      } on CursorClientException catch (e) {
        if (e.statusCode != 409) {
          rethrow;
        }
        // Agent busy or stale — start a fresh agent.
        _agentId = null;
      }
    }

    return _createAgent(
      apiKey: apiKey,
      prompt: prompt,
      modelId: modelId,
    );
  }

  Future<({String agentId, String runId})> _createAgent({
    required String apiKey,
    required String prompt,
    required String modelId,
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/agents');
    final response = await _activeClient!.post(
      uri,
      headers: _headers(apiKey),
      body: jsonEncode({
        'name': 'Flowdesk Interview',
        'prompt': {'text': prompt},
        'model': {'id': modelId},
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw cursorExceptionForStatus(response.statusCode, response.body);
    }

    final json = jsonDecode(response.body);
    if (json is! Map) {
      throw Exception('Unexpected Cursor create-agent response.');
    }

    final agent = Map<String, dynamic>.from(json['agent'] as Map? ?? const {});
    final run = Map<String, dynamic>.from(json['run'] as Map? ?? const {});
    final agentId = agent['id']?.toString();
    final runId = run['id']?.toString();
    if (agentId == null || runId == null) {
      throw Exception('Cursor create-agent response missing agent/run ids.');
    }

    _agentId = agentId;
    return (agentId: agentId, runId: runId);
  }

  Future<({String agentId, String runId})> _createFollowUpRun({
    required String apiKey,
    required String agentId,
    required String prompt,
    required String modelId,
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/agents/$agentId/runs');
    final response = await _activeClient!.post(
      uri,
      headers: _headers(apiKey),
      body: jsonEncode({
        'prompt': {'text': prompt},
        'model': {'id': modelId},
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw cursorExceptionForStatus(response.statusCode, response.body);
    }

    final json = jsonDecode(response.body);
    if (json is! Map) {
      throw Exception('Unexpected Cursor create-run response.');
    }

    final run = Map<String, dynamic>.from(json['run'] as Map? ?? json);
    final runId = run['id']?.toString();
    if (runId == null) {
      throw Exception('Cursor create-run response missing run id.');
    }

    return (agentId: agentId, runId: runId);
  }

  Stream<StreamResponse> _streamRun({
    required String apiKey,
    required String agentId,
    required String runId,
  }) async* {
    final uri = Uri.parse('$_baseUrl/v1/agents/$agentId/runs/$runId/stream');
    final request = http.Request('GET', uri)
      ..headers.addAll(_headers(apiKey))
      ..headers['Accept'] = 'text/event-stream';

    final response = await _activeClient!.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.stream.bytesToString();
      throw cursorExceptionForStatus(response.statusCode, body);
    }

    var currentEvent = '';
    final buffer = StringBuffer();

    await for (final line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
      if (_cancelled) {
        break;
      }

      if (line.isEmpty) {
        yield* _handleSseEvent(currentEvent, buffer.toString());
        currentEvent = '';
        buffer.clear();
        continue;
      }

      if (line.startsWith('event:')) {
        currentEvent = line.substring(6).trim();
        continue;
      }
      if (line.startsWith('data:')) {
        buffer.write(line.substring(5).trim());
      }
    }

    if (buffer.isNotEmpty) {
      yield* _handleSseEvent(currentEvent, buffer.toString());
    }
  }

  Stream<StreamResponse> _handleSseEvent(String event, String dataJson) async* {
    if (dataJson.isEmpty) {
      return;
    }

    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(dataJson);
      if (decoded is Map) {
        data = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return;
    }

    if (event == 'assistant' || event == 'interaction_update') {
      final text = data?['text']?.toString();
      if (text != null && text.isNotEmpty) {
        yield StreamResponse(delta: text);
      }
      return;
    }

    if (event == 'result') {
      final text = data?['text']?.toString();
      if (text != null && text.isNotEmpty) {
        yield StreamResponse(delta: text);
      }
    }
  }

  Map<String, String> _headers(String apiKey) {
    final basic = base64Encode(utf8.encode('$apiKey:'));
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Basic $basic',
    };
  }

  @override
  void stopGeneration() {
    _cancelled = true;
    _activeClient?.close();
    _activeClient = null;
  }
}
