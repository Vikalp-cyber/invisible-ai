class CursorRuntimeConfig {
  const CursorRuntimeConfig({
    required this.apiKeys,
    this.modelId = CursorModelIds.defaultChat,
  });

  final List<String> apiKeys;
  final String modelId;
}

class CursorModelIds {
  static const defaultChat = 'composer-2.5';
}
