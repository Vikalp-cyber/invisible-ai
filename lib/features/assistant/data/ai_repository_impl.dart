import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/models/chat_message.dart';
import '../domain/models/groq_runtime_config.dart';
import '../domain/repositories/ai_provider_interface.dart';
import '../../../services/secure_storage_service.dart';
import '../../../services/preference_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import 'providers/gemini_provider.dart';
import 'providers/openai_provider.dart';
import 'providers/anthropic_provider.dart';
import 'providers/ollama_provider.dart';
import 'providers/groq_provider.dart';
import 'providers/groq_exceptions.dart';

class AIRepository {
  final SecureStorageService _secureStorage;
  final PreferenceService _prefs;

  /// Session Groq keys from backend only — never written to [SecureStorageService].
  List<String> _groqApiKeys = const [];

  /// Current position in the key pool (round-robin).
  int _groqKeyIndex = 0;

  List<GroqModelOption> _groqModels = const [];
  String? _groqDefaultModelId;

  final Map<AIProviderType, AIProvider> _providers = {
    AIProviderType.gemini: GeminiProvider(),
    AIProviderType.openai: OpenAIProvider(),
    AIProviderType.anthropic: AnthropicProvider(),
    AIProviderType.ollama: OllamaProvider(),
    AIProviderType.groq: GroqProvider(),
  };

  AIProviderType _currentProviderType = AIProviderType.groq;

  AIRepository(this._secureStorage, this._prefs);

  void applyGroqRuntimeConfig(GroqRuntimeConfig config) {
    _groqApiKeys = List<String>.from(config.apiKeys);
    _groqKeyIndex = 0; // reset to first key on fresh config
    _groqModels = List<GroqModelOption>.from(config.models);
    _groqDefaultModelId = config.resolvedDefaultModelId;
    // Do not persist the Groq secret; clear any legacy locally stored key.
    unawaited(_secureStorage.deleteApiKey(AIProviderType.groq));
    debugPrint(
      '[AIRepository] Groq config applied: ${_groqApiKeys.length} key(s), '
      '${_groqModels.length} model(s)',
    );
  }

  void clearGroqRuntimeConfig() {
    _groqApiKeys = const [];
    _groqKeyIndex = 0;
    _groqModels = const [];
    _groqDefaultModelId = null;
  }

  List<GroqModelOption> get groqModelOptions => List.unmodifiable(_groqModels);

  String? _resolveGroqModelId() {
    final saved = _prefs.getString(AppConstants.keyGroqModelId);
    if (saved.isNotEmpty &&
        _groqModels.any((m) => m.id == saved)) {
      return saved;
    }
    return _groqDefaultModelId ??
        (_groqModels.isNotEmpty ? _groqModels.first.id : null);
  }

  AIProvider get currentProvider => _providers[_currentProviderType]!;

  AIProviderType get currentProviderType => _currentProviderType;

  void setProvider(AIProviderType type) {
    _currentProviderType = type;
  }

  // ── Groq Key Helpers ──────────────────────────────────────────────────────

  /// Returns the current Groq API key from the pool.
  String? get _currentGroqKey =>
      _groqApiKeys.isNotEmpty ? _groqApiKeys[_groqKeyIndex] : null;

  /// Advances to the next key in the pool (wraps around).
  /// Returns `true` if a new key is now active, `false` if we've cycled back
  /// to the starting position (all keys exhausted).
  bool _rotateGroqKey(int startIndex) {
    final nextIndex = (_groqKeyIndex + 1) % _groqApiKeys.length;
    _groqKeyIndex = nextIndex;

    debugPrint(
      '[AIRepository] Groq key rotated → index $_groqKeyIndex '
      '(${_maskKey(_groqApiKeys[_groqKeyIndex])})',
    );

    // If we've looped back to where we started, all keys are exhausted.
    return _groqKeyIndex != startIndex;
  }

  /// Mask a key for safe debug logging.
  String _maskKey(String key) {
    if (key.length <= 8) return '***';
    return '${key.substring(0, 4)}***${key.substring(key.length - 4)}';
  }

  // ── Stream Generation ─────────────────────────────────────────────────────

  /// Generates a streaming response using the currently selected provider.
  ///
  /// For **Groq**, automatically rotates through available API keys on
  /// retriable failures (429 rate-limit, 500 server error, 401/403 auth).
  Stream<StreamResponse> generateStream(
    List<ChatMessage> history,
    String prompt, {
    Uint8List? imageBytes,
  }) async* {
    final provider = currentProvider;
    String? apiKey;
    String? providerModelId;

    if (provider.requiresApiKey) {
      if (provider.type == AIProviderType.groq) {
        apiKey = _currentGroqKey;
        providerModelId = _resolveGroqModelId();
        if (apiKey == null || apiKey.isEmpty) {
          throw Exception(
            'Groq is not ready yet. Stay signed in and ensure the backend '
            'returns your key at the configured client-config route.',
          );
        }
      } else {
        apiKey = await _secureStorage.getApiKey(provider.type);
        if (apiKey == null || apiKey.isEmpty) {
          throw Exception(
            'API key not found for ${provider.type.displayName}. Please configure it in Settings.',
          );
        }
      }
    }

    final styledPrompt = '''
${AppStrings.interviewCopilotStylePrompt}

User question:
$prompt
''';

    // ── Non-Groq providers: single attempt, no fallback ───────────────────
    if (provider.type != AIProviderType.groq || _groqApiKeys.length <= 1) {
      yield* provider.generateStream(
        history,
        styledPrompt,
        apiKey: apiKey,
        imageBytes: imageBytes,
        providerModelId: providerModelId,
      );
      return;
    }

    // ── Groq with multiple keys: retry with fallback on retriable errors ──
    final startIndex = _groqKeyIndex;

    do {
      final currentKey = _groqApiKeys[_groqKeyIndex];
      try {
        debugPrint(
          '[AIRepository] Groq attempt with key index $_groqKeyIndex '
          '(${_maskKey(currentKey)})',
        );

        yield* provider.generateStream(
          history,
          styledPrompt,
          apiKey: currentKey,
          imageBytes: imageBytes,
          providerModelId: providerModelId,
        );

        // Success — stream completed without error.
        return;
      } on GroqApiException catch (e) {
        debugPrint(
          '[AIRepository] Groq key ${_maskKey(currentKey)} failed: $e',
        );

        if (!e.isRetriable) {
          // Non-retriable (e.g. 400 bad request) — fail immediately.
          rethrow;
        }

        // Retriable error — rotate to next key.
        final hasMore = _rotateGroqKey(startIndex);
        if (!hasMore) {
          // All keys exhausted — throw the last error.
          debugPrint(
            '[AIRepository] All ${_groqApiKeys.length} Groq key(s) exhausted.',
          );
          rethrow;
        }

        // Small delay before retrying with the next key.
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    } while (true);
  }


  /// Cancels the ongoing generation.
  void stopGeneration() {
    currentProvider.stopGeneration();
  }
}

