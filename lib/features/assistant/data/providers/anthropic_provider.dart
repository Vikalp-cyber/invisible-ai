import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../domain/models/chat_message.dart';
import '../../domain/repositories/ai_provider_interface.dart';

class AnthropicProvider implements AIProvider {
  @override
  AIProviderType get type => AIProviderType.anthropic;

  @override
  bool get requiresApiKey => true;

  http.Client? _client;

  @override
  Stream<StreamResponse> generateStream(
    List<ChatMessage> history,
    String prompt, {
    String? apiKey,
    Uint8List? imageBytes,
  }) async* {
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API key is required for Anthropic Claude.');
    }

    _client = http.Client();

    final List<Map<String, dynamic>> messages = history.map((msg) {
      return {
        'role': msg.role == MessageRole.user ? 'user' : 'assistant',
        'content': msg.content,
      };
    }).toList();

    // Add current prompt
    if (imageBytes != null) {
      final base64Image = base64Encode(imageBytes);
      messages.add({
        'role': 'user',
        'content': [
          {
            'type': 'image',
            'source': {
              'type': 'base64',
              'media_type': 'image/png',
              'data': base64Image,
            }
          },
          {'type': 'text', 'text': prompt},
        ]
      });
    } else {
      messages.add({'role': 'user', 'content': prompt});
    }

    final request = http.Request(
      'POST',
      Uri.parse('https://api.anthropic.com/v1/messages'),
    );
    request.headers.addAll({
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01',
    });
    request.body = jsonEncode({
      'model': 'claude-3-opus-20240229',
      'max_tokens': 4096,
      'messages': messages,
      'stream': true,
    });

    try {
      final response = await _client!.send(request);

      if (response.statusCode != 200) {
        final errorResponse = await response.stream.bytesToString();
        throw Exception('Anthropic Error: ${response.statusCode} - $errorResponse');
      }

      await for (final chunk in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (chunk.trim().isEmpty) continue;
        if (chunk.startsWith('event:')) continue;
        if (chunk.startsWith('data: ')) {
          final dataStr = chunk.substring(6);
          try {
            final json = jsonDecode(dataStr);
            if (json['type'] == 'content_block_delta') {
              yield StreamResponse(delta: json['delta']['text'] as String);
            }
          } catch (e) {
            // Ignore parse errors for partial chunks
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
