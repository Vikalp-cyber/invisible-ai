import 'package:flutter/foundation.dart';
import '../domain/models/chat_message.dart';
import '../domain/models/cursor_runtime_config.dart';
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
import 'providers/cursor_provider.dart';
import 'providers/cursor_exceptions.dart';

class AIRepository {
  final SecureStorageService _secureStorage;
  final PreferenceService _prefs;

  /// Session Groq keys applied from local settings (multi-key fallback pool).
  List<String> _groqApiKeys = const [];

  /// Current position in the key pool (round-robin).
  int _groqKeyIndex = 0;

  List<GroqModelOption> _groqModels = const [];
  String? _groqDefaultModelId;

  /// Session Cursor keys applied from local settings (multi-key fallback pool).
  List<String> _cursorApiKeys = const [];
  int _cursorKeyIndex = 0;
  String? _cursorModelId;

  final Map<AIProviderType, AIProvider> _providers = {
    AIProviderType.gemini: GeminiProvider(),
    AIProviderType.openai: OpenAIProvider(),
    AIProviderType.anthropic: AnthropicProvider(),
    AIProviderType.ollama: OllamaProvider(),
    AIProviderType.groq: GroqProvider(),
    AIProviderType.cursor: CursorProvider(),
  };

  AIProviderType _currentProviderType = AIProviderType.groq;

  /// Candidate resume text injected into every interview-styled prompt.
  String _resumeText = '';

  AIRepository(this._secureStorage, this._prefs);

  void applyGroqRuntimeConfig(GroqRuntimeConfig config) {
    _groqApiKeys = List<String>.from(config.apiKeys);
    _groqKeyIndex = 0; // reset to first key on fresh config
    var models = List<GroqModelOption>.from(config.models);
    if (models.isEmpty) {
      final id = GroqModelIds.canonicalize(config.chatModel);
      if (id != null) {
        models = [GroqModelOption(id: id)];
      }
    }
    _groqModels = models;
    _groqDefaultModelId = config.resolvedDefaultModelId;
    (_providers[AIProviderType.groq] as GroqProvider)
        .applyChatBaseUrl(config.chatBaseUrl);
    if (_cursorApiKeys.isEmpty) {
      _currentProviderType = AIProviderType.groq;
    }
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
    (_providers[AIProviderType.groq] as GroqProvider).applyChatBaseUrl(null);
    _selectDefaultProvider();
  }

  void applyCursorRuntimeConfig(CursorRuntimeConfig config) {
    _cursorApiKeys = List<String>.from(config.apiKeys);
    _cursorKeyIndex = 0;
    _cursorModelId = config.modelId;
    _currentProviderType = AIProviderType.cursor;
    debugPrint(
      '[AIRepository] Cursor config applied: ${_cursorApiKeys.length} key(s)',
    );
  }

  void clearCursorRuntimeConfig() {
    _cursorApiKeys = const [];
    _cursorKeyIndex = 0;
    _cursorModelId = null;
    _selectDefaultProvider();
  }

  void resetCursorChatSession() {
    (_providers[AIProviderType.cursor] as CursorProvider).resetSession();
  }

  void _selectDefaultProvider() {
    if (_cursorApiKeys.isNotEmpty) {
      _currentProviderType = AIProviderType.cursor;
    } else if (_groqApiKeys.isNotEmpty) {
      _currentProviderType = AIProviderType.groq;
    }
  }

  void setResumeText(String? text) {
    _resumeText = (text ?? '').trim();
    if (_resumeText.length > AppConstants.maxResumeChars) {
      _resumeText = _resumeText.substring(0, AppConstants.maxResumeChars);
    }
  }

  bool get hasResume => _resumeText.isNotEmpty;

  List<GroqModelOption> get groqModelOptions => List.unmodifiable(_groqModels);

  String? _resolveGroqModelId() {
    final saved = _prefs.getString(AppConstants.keyGroqModelId).trim();
    if (saved.isNotEmpty) {
      final migrated = GroqModelIds.canonicalize(saved);
      // Prefer migrated id when the saved one was shut down by Groq.
      if (migrated != null && migrated != saved) {
        return migrated;
      }
      if (_groqModels.any((m) => m.id == saved)) {
        return saved;
      }
      if (migrated != null && _groqModels.any((m) => m.id == migrated)) {
        return migrated;
      }
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

  String? get _currentCursorKey =>
      _cursorApiKeys.isNotEmpty ? _cursorApiKeys[_cursorKeyIndex] : null;

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

  bool _rotateCursorKey(int startIndex) {
    final nextIndex = (_cursorKeyIndex + 1) % _cursorApiKeys.length;
    _cursorKeyIndex = nextIndex;
    debugPrint(
      '[AIRepository] Cursor key rotated → index $_cursorKeyIndex '
      '(${_maskKey(_cursorApiKeys[_cursorKeyIndex])})',
    );
    return _cursorKeyIndex != startIndex;
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
  /// retriable failures (429 / 402 / 408 limits, 401/403 auth, 5xx server).
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
            'No Groq API key configured. Add one or more keys in Settings.',
          );
        }
      } else if (provider.type == AIProviderType.cursor) {
        apiKey = _currentCursorKey;
        providerModelId = _cursorModelId ?? CursorModelIds.defaultChat;
        if (apiKey == null || apiKey.isEmpty) {
          throw Exception(
            'No Cursor API key configured. Add one in Settings → API Keys.',
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

    final resumeBlock = _resumeText.isEmpty
        ? '(no resume uploaded — keep answers general; do not invent a personal background)'
        : _resumeText;

    final styledPrompt = '''
${AppStrings.interviewCopilotStylePrompt}

Candidate resume (ground truth for experience, skills, projects, education):
---
$resumeBlock
---

User question:
$prompt
''';

    if (provider.type == AIProviderType.cursor && _cursorApiKeys.length > 1) {
      yield* _generateWithCursorKeyFallback(
        history: history,
        styledPrompt: styledPrompt,
        imageBytes: imageBytes,
        providerModelId: providerModelId,
      );
      return;
    }

    if (provider.type == AIProviderType.groq && _groqApiKeys.length > 1) {
      yield* _generateWithGroqKeyFallback(
        history: history,
        styledPrompt: styledPrompt,
        imageBytes: imageBytes,
        providerModelId: providerModelId,
      );
      return;
    }

    yield* provider.generateStream(
      history,
      styledPrompt,
      apiKey: apiKey,
      imageBytes: imageBytes,
      providerModelId: providerModelId,
    );
  }

  Stream<StreamResponse> _generateWithGroqKeyFallback({
    required List<ChatMessage> history,
    required String styledPrompt,
    Uint8List? imageBytes,
    String? providerModelId,
  }) async* {
    final provider = _providers[AIProviderType.groq]!;
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
        return;
      } on GroqApiException catch (e) {
        debugPrint(
          '[AIRepository] Groq key ${_maskKey(currentKey)} failed: $e',
        );
        if (!e.isRetriable) {
          rethrow;
        }
        final hasMore = _rotateGroqKey(startIndex);
        if (!hasMore) {
          rethrow;
        }
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    } while (true);
  }

  Stream<StreamResponse> _generateWithCursorKeyFallback({
    required List<ChatMessage> history,
    required String styledPrompt,
    Uint8List? imageBytes,
    String? providerModelId,
  }) async* {
    final provider = _providers[AIProviderType.cursor]!;
    final startIndex = _cursorKeyIndex;

    do {
      final currentKey = _cursorApiKeys[_cursorKeyIndex];
      try {
        debugPrint(
          '[AIRepository] Cursor attempt with key index $_cursorKeyIndex '
          '(${_maskKey(currentKey)})',
        );

        yield* provider.generateStream(
          history,
          styledPrompt,
          apiKey: currentKey,
          imageBytes: imageBytes,
          providerModelId: providerModelId,
        );
        return;
      } on CursorApiException catch (e) {
        debugPrint(
          '[AIRepository] Cursor key ${_maskKey(currentKey)} failed: $e',
        );
        if (!e.isRetriable) {
          rethrow;
        }
        final hasMore = _rotateCursorKey(startIndex);
        if (!hasMore) {
          rethrow;
        }
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    } while (true);
  }


  /// Cancels the ongoing generation.
  void stopGeneration() {
    currentProvider.stopGeneration();
  }
}

