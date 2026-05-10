import 'dart:async';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/repositories/ai_provider_interface.dart';

class GeminiProvider implements AIProvider {
  @override
  AIProviderType get type => AIProviderType.gemini;

  @override
  bool get requiresApiKey => true;

  // Track the current generation to allow cancellation.
  StreamSubscription? _subscription;

  @override
  Stream<StreamResponse> generateStream(
    List<ChatMessage> history,
    String prompt, {
    String? apiKey,
    Uint8List? imageBytes,
    String? providerModelId,
  }) async* {
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('API key is required for Google Gemini.');
    }

    final model = GenerativeModel(model: 'gemini-2.0-flash', apiKey: apiKey);

    // Convert history to Gemini Content format.
    // Exclude the current prompt as it will be sent separately.
    final chatHistory = history.map((msg) {
      final role = msg.role == MessageRole.user ? 'user' : 'model';
      return Content(role, [TextPart(msg.content)]);
    }).toList();

    final chat = model.startChat(history: chatHistory);

    try {
      final contentParts = <Part>[TextPart(prompt)];
      if (imageBytes != null) {
        contentParts.add(DataPart('image/png', imageBytes));
      }
      
      final stream = chat.sendMessageStream(Content.model(contentParts));

      await for (final response in stream) {
        if (response.text != null) {
          yield StreamResponse(delta: response.text!);
        }
      }
    } catch (e) {
      throw Exception('Gemini Error: $e');
    }
  }

  @override
  void stopGeneration() {
    _subscription?.cancel();
    _subscription = null;
  }
}
