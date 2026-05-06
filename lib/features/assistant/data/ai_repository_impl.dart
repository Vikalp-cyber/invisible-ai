import 'dart:typed_data';
import '../domain/models/chat_message.dart';
import '../domain/repositories/ai_provider_interface.dart';
import '../../../services/secure_storage_service.dart';
import '../../../core/constants/app_strings.dart';
import 'providers/gemini_provider.dart';
import 'providers/openai_provider.dart';
import 'providers/anthropic_provider.dart';
import 'providers/ollama_provider.dart';
import 'providers/groq_provider.dart';

class AIRepository {
  final SecureStorageService _secureStorage;
  
  final Map<AIProviderType, AIProvider> _providers = {
    AIProviderType.gemini: GeminiProvider(),
    AIProviderType.openai: OpenAIProvider(),
    AIProviderType.anthropic: AnthropicProvider(),
    AIProviderType.ollama: OllamaProvider(),
    AIProviderType.groq: GroqProvider(),
  };

  AIProviderType _currentProviderType = AIProviderType.groq;

  AIRepository(this._secureStorage);

  AIProvider get currentProvider => _providers[_currentProviderType]!;

  AIProviderType get currentProviderType => _currentProviderType;

  void setProvider(AIProviderType type) {
    _currentProviderType = type;
  }

  /// Generates a streaming response using the currently selected provider.
  Stream<String> generateStream(
    List<ChatMessage> history,
    String prompt, {
    Uint8List? imageBytes,
  }) async* {
    final provider = currentProvider;
    String? apiKey;

    if (provider.requiresApiKey) {
      apiKey = await _secureStorage.getApiKey(provider.type);
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('API key not found for ${provider.type.displayName}. Please configure it in Settings.');
      }
    }

    final styledPrompt = '''
${AppStrings.interviewCopilotStylePrompt}

User question:
$prompt
''';

    yield* provider.generateStream(
      history,
      styledPrompt,
      apiKey: apiKey,
      imageBytes: imageBytes,
    );
  }

  /// Cancels the ongoing generation.
  void stopGeneration() {
    currentProvider.stopGeneration();
  }
}
