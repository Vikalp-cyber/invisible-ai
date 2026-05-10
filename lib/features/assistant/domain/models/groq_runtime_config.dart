/// Resolved Groq credentials + model list from the backend (in-memory only).
///
/// Supports **multiple API keys** for automatic fallback rotation. When
/// the first key hits a rate-limit or error, the caller can cycle to the next.
class GroqRuntimeConfig {
  const GroqRuntimeConfig({
    required this.apiKeys,
    required this.models,
    this.defaultModel,
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
      defaultModel: defaultModel,
    );
  }

  /// Ordered pool of Groq API keys. At least one entry is guaranteed.
  final List<String> apiKeys;
  final List<GroqModelOption> models;
  final String? defaultModel;

  /// Number of keys available for rotation.
  int get keyCount => apiKeys.length;

  /// The first key in the pool (primary).
  String get primaryKey => apiKeys.first;

  String? get resolvedDefaultModelId {
    if (defaultModel != null && defaultModel!.isNotEmpty) {
      return defaultModel;
    }
    if (models.isEmpty) {
      return null;
    }
    return models.first.id;
  }
}

class GroqModelOption {
  const GroqModelOption({required this.id, this.label});

  final String id;
  final String? label;
}
