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
  Stream<String> generateStream(
    List<ChatMessage> history,
    String prompt, {
    String? apiKey,
    Uint8List? imageBytes,
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

      final controller = StreamController<String>();

      _subscription = stream.listen(
        (GenerateContentResponse response) {
          if (response.text != null) {
            controller.add(response.text!);
          }
        },
        onError: (error) => controller.addError(error),
        onDone: () => controller.close(),
      );

      yield* controller.stream;
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
