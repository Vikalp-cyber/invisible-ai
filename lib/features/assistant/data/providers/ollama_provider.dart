import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../domain/models/chat_message.dart';
import '../../domain/repositories/ai_provider_interface.dart';

class OllamaProvider implements AIProvider {
  @override
  AIProviderType get type => AIProviderType.ollama;

  @override
  bool get requiresApiKey => false;

  http.Client? _client;

  @override
  Stream<StreamResponse> generateStream(
    List<ChatMessage> history,
    String prompt, {
    String? apiKey,
    Uint8List? imageBytes,
  }) async* {
    _client = http.Client();

    final List<Map<String, dynamic>> messages = history.map((msg) {
      return {
        'role': msg.role == MessageRole.user ? 'user' : 'assistant',
        'content': msg.content,
      };
    }).toList();

    if (imageBytes != null) {
      messages.add({
        'role': 'user',
        'content': prompt,
        'images': [base64Encode(imageBytes)]
      });
    } else {
      messages.add({'role': 'user', 'content': prompt});
    }

    final request = http.Request(
      'POST',
      Uri.parse('http://localhost:11434/api/chat'),
    );
    request.headers.addAll({
      'Content-Type': 'application/json',
    });
    request.body = jsonEncode({
      'model': 'llama3', // Default local model
      'messages': messages,
      'stream': true,
    });

    try {
      final response = await _client!.send(request);

      if (response.statusCode != 200) {
        final errorResponse = await response.stream.bytesToString(); // Consume stream
        throw Exception('Ollama Error (${response.statusCode}): $errorResponse');
      }

      await for (final chunk in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (chunk.trim().isEmpty) continue;
        try {
          final json = jsonDecode(chunk);
          if (json.containsKey('message')) {
            yield StreamResponse(delta: json['message']['content'] as String);
          }
        } catch (e) {
          // Ignore parse errors for partial chunks
        }
      }
    } on http.ClientException {
      throw Exception('Failed to connect to Ollama. Make sure it is running locally on port 11434.');
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
