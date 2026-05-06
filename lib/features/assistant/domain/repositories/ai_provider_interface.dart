import 'dart:typed_data';
import '../models/chat_message.dart';

/// Supported AI providers in the system.
enum AIProviderType {
  gemini,
  openai,
  anthropic,
  ollama,
  groq,
}

extension AIProviderTypeX on AIProviderType {
  String get displayName {
    switch (this) {
      case AIProviderType.gemini:
        return 'Google Gemini';
      case AIProviderType.openai:
        return 'OpenAI';
      case AIProviderType.anthropic:
        return 'Anthropic Claude';
      case AIProviderType.ollama:
        return 'Local Ollama';
      case AIProviderType.groq:
        return 'Groq LPU';
    }
  }
}

/// Abstract base class that all AI providers must implement.
abstract class AIProvider {
  /// The type identifier for this provider.
  AIProviderType get type;

  /// Whether this provider requires an API key to function.
  bool get requiresApiKey;

  /// Generates a streaming response from the AI model.
  /// Yields chunks of text as they arrive from the network.
  /// Throws an exception if generation fails.
  Stream<String> generateStream(
    List<ChatMessage> history,
    String prompt, {
    String? apiKey,
    Uint8List? imageBytes,
  });

  /// Cancels an ongoing generation.
  void stopGeneration();
}
