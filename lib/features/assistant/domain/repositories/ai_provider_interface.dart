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

/// ── Stream Response ────────────────────────────────────────────────────────
/// A single chunk of a streaming AI response, containing text and metadata.
class StreamResponse {
  /// The partial text content received in this chunk.
  final String? delta;

  /// Token usage metadata (usually present in the final chunk).
  final ChatMessageUsage? usage;

  StreamResponse({this.delta, this.usage});
}

/// Abstract base class that all AI providers must implement.
abstract class AIProvider {
  /// The type identifier for this provider.
  AIProviderType get type;

  /// Whether this provider requires an API key to function.
  bool get requiresApiKey;

  /// Generates a streaming response from the AI model.
  /// Yields chunks of [StreamResponse] as they arrive from the network.
  /// Throws an exception if generation fails.
  Stream<StreamResponse> generateStream(
    List<ChatMessage> history,
    String prompt, {
    String? apiKey,
    Uint8List? imageBytes,
  });

  /// Cancels an ongoing generation.
  void stopGeneration();
}

