/// Groq OpenAI-style chat model ids: trim, map known deprecations, safe default for requests.
abstract final class GroqModelIds {
  GroqModelIds._();

  /// Default when the client has no model id (matches Groq guidance for Llama 3.3 70B).
  static const String defaultChat = 'llama-3.3-70b-versatile';

  static const Map<String, String> _deprecated = {
    'llama-3.1-70b-versatile': defaultChat,
    'llama3-70b-8192': defaultChat,
  };

  /// Returns `null` when [id] is null or blank after trim.
  static String? canonicalize(String? id) {
    final t = id?.trim();
    if (t == null || t.isEmpty) {
      return null;
    }
    return _deprecated[t] ?? t;
  }

  /// Model id sent to `chat/completions` — never empty.
  static String forChatRequest(String? providerModelId) {
    return canonicalize(providerModelId) ?? defaultChat;
  }
}

/// Resolved Groq credentials + model list from the backend (in-memory only).
///
/// Supports **multiple API keys** for automatic fallback rotation. When
/// the first key hits a rate-limit or error, the caller can cycle to the next.
///
/// New API shape: `groq.baseUrl`, `groq.model`, `groq.keys[]` (objects with
/// `apiKey`, `isActive`, `isDefault`, …). Legacy: flat `apiKey` / `apiKeys` / `models`.
class GroqRuntimeConfig {
  const GroqRuntimeConfig({
    required this.apiKeys,
    required this.models,
    this.defaultModel,
    this.chatBaseUrl,
    this.chatModel,
  });

  /// Convenience constructor for a single key (backward-compat).
  factory GroqRuntimeConfig.single({
    required String apiKey,
    required List<GroqModelOption> models,
    String? defaultModel,
  }) {
    return GroqRuntimeConfig(
      apiKeys: [apiKey],
      models: models,
      defaultModel: GroqModelIds.canonicalize(defaultModel),
      chatBaseUrl: null,
      chatModel: null,
    );
  }

  /// Ordered pool of Groq API keys (default+active first per server order, then fallback).
  final List<String> apiKeys;
  final List<GroqModelOption> models;
  final String? defaultModel;

  /// OpenAI-compatible chat base URL, e.g. `https://api.groq.com/openai/v1`.
  final String? chatBaseUrl;

  /// Single model id from `groq.model` when the server does not send `models[]`.
  final String? chatModel;

  /// Number of keys available for rotation.
  int get keyCount => apiKeys.length;

  /// The first key in the pool (primary).
  String get primaryKey => apiKeys.first;

  String? get resolvedDefaultModelId {
    final d = GroqModelIds.canonicalize(defaultModel);
    if (d != null) {
      return d;
    }
    final c = GroqModelIds.canonicalize(chatModel);
    if (c != null) {
      return c;
    }
    if (models.isEmpty) {
      return null;
    }
    return GroqModelIds.canonicalize(models.first.id) ?? models.first.id.trim();
  }
}

class GroqModelOption {
  const GroqModelOption({required this.id, this.label});

  final String id;
  final String? label;
}
