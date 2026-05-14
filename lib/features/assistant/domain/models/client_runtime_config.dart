import 'groq_runtime_config.dart';

/// Full signed-in client secrets bundle from `GET /api/client-config`.
///
/// Legacy `GET /api/groq/client-config` returns the same Groq fields at the
/// top level (no `groq` / `deepgram` wrapper) — the repository maps that shape.
class ClientRuntimeConfig {
  const ClientRuntimeConfig({
    required this.groq,
    this.deepgram,
    this.user,
  });

  final GroqRuntimeConfig groq;
  final DeepgramRuntimeConfig? deepgram;

  /// Optional signed-in user quota row from `GET /api/client-config`.
  final ClientUserRuntime? user;
}

/// Subset of `user` from client-config JSON.
class ClientUserRuntime {
  const ClientUserRuntime({
    required this.id,
    this.email,
    this.tokensUsed,
    this.tokenLimit,
    this.tokensRemaining,
    this.isActive,
  });

  final String id;
  final String? email;
  final int? tokensUsed;
  final int? tokenLimit;
  final int? tokensRemaining;
  final bool? isActive;
}

/// Deepgram streaming config (in-memory only).
///
/// New shape: `deepgram.baseUrl`, `deepgram.keys[]` (same row shape as Groq).
/// [apiKeys] may be empty — do not start live speech until keys exist.
class DeepgramRuntimeConfig {
  const DeepgramRuntimeConfig({
    required this.apiKeys,
    this.baseUrl,
  });

  final List<String> apiKeys;

  /// REST/streaming base, e.g. `https://api.deepgram.com/v1`.
  final String? baseUrl;

  bool get hasKeys => apiKeys.isNotEmpty;

  String? get primaryKey => apiKeys.isNotEmpty ? apiKeys.first : null;
}
