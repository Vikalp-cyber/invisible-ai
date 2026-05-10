import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../domain/models/chat_message.dart';
import '../../domain/repositories/ai_provider_interface.dart';

class OpenAIProvider implements AIProvider {
  @override
  AIProviderType get type => AIProviderType.openai;

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
      throw Exception('API key is required for OpenAI.');
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
          {'type': 'text', 'text': prompt},
          {
            'type': 'image_url',
            'image_url': {'url': 'data:image/png;base64,$base64Image'}
          }
        ]
      });
    } else {
      messages.add({'role': 'user', 'content': prompt});
    }

    final request = http.Request(
      'POST',
      Uri.parse('https://api.openai.com/v1/chat/completions'),
    );
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    });
    request.body = jsonEncode({
      'model': 'gpt-4o', // Default model
      'messages': messages,
      'stream': true,
    });

    try {
      final response = await _client!.send(request);

      if (response.statusCode != 200) {
        final errorResponse = await response.stream.bytesToString();
        throw Exception('OpenAI Error: ${response.statusCode} - $errorResponse');
      }

      await for (final chunk in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (chunk.trim().isEmpty) continue;
        if (chunk.startsWith('data: [DONE]')) break;
        if (chunk.startsWith('data: ')) {
          final dataStr = chunk.substring(6);
          try {
            final json = jsonDecode(dataStr);
            final delta = json['choices'][0]['delta'];
            if (delta.containsKey('content')) {
              yield StreamResponse(delta: delta['content'] as String);
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
