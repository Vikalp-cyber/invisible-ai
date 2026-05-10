import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../domain/models/chat_message.dart';
import '../../domain/repositories/ai_provider_interface.dart';
import 'groq_exceptions.dart';

class GroqProvider implements AIProvider {
  @override
  AIProviderType get type => AIProviderType.groq;

  @override
  bool get requiresApiKey => true;

  http.Client? _client;

  @override
  Stream<StreamResponse> generateStream(
    List<ChatMessage> history,
    String prompt, {
    String? apiKey,
    Uint8List? imageBytes,
    String? providerModelId,
  }) async* {
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API key is required for Groq.');
    }

    if (imageBytes != null) {
      throw Exception('Groq currently does not support Vision/Image uploads on this model.');
    }

    _client = http.Client();

    final messages = history.map((msg) {
      return {
        'role': msg.role == MessageRole.user ? 'user' : 'assistant',
        'content': msg.content,
      };
    }).toList();

    // Add current prompt
    messages.add({'role': 'user', 'content': prompt});

    final request = http.Request(
      'POST',
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
    );
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    });
    final model =
        (providerModelId != null && providerModelId.isNotEmpty)
            ? providerModelId
            : 'llama-3.3-70b-versatile';
    request.body = jsonEncode({
      'model': model,
      'messages': messages,
      'stream': true,
      'stream_options': {'include_usage': true}, // Required to get usage in stream
    });

    try {
      final response = await _client!.send(request);

      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        final code = response.statusCode;

        // Throw typed exceptions so the fallback layer can decide to retry.
        if (code == 429) {
          throw GroqRateLimitException(code, errorBody);
        } else if (code == 401 || code == 403) {
          throw GroqAuthException(code, errorBody);
        } else if (code >= 500) {
          throw GroqServerException(code, errorBody);
        } else {
          throw GroqClientException(code, errorBody);
        }
      }

      await for (final chunk in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (chunk.trim().isEmpty) continue;
        if (chunk.startsWith('data: [DONE]')) break;
        if (chunk.startsWith('data: ')) {
          final dataStr = chunk.substring(6);
          try {
            final json = jsonDecode(dataStr);

            // Handle content delta
            if (json['choices'] != null && json['choices'].isNotEmpty) {
              final delta = json['choices'][0]['delta'];
              if (delta.containsKey('content')) {
                yield StreamResponse(delta: delta['content'] as String);
              }
            }

            // Handle usage (usually in the last chunk or a separate chunk if stream_options is set)
            if (json.containsKey('usage') && json['usage'] != null) {
              final usageJson = json['usage'];
              yield StreamResponse(
                usage: ChatMessageUsage(
                  promptTokens: usageJson['prompt_tokens'] ?? 0,
                  completionTokens: usageJson['completion_tokens'] ?? 0,
                  totalTokens: usageJson['total_tokens'] ?? 0,
                ),
              );
            }
          } catch (e) {
            // Re-throw Groq API exceptions; ignore JSON parse errors for partial chunks.
            if (e is GroqApiException) rethrow;
          }
        }
      }
    } finally {
      _client?.close();
      _client = null;
    }

  }

  @override
  void stopGeneration() {
    _client?.close();
    _client = null;
  }
}
