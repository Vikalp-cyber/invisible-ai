// Typed exceptions thrown by [GroqProvider] so the fallback logic in
// [AIRepository] can decide whether to retry with the next API key.

/// Base class for all Groq API errors.
class GroqApiException implements Exception {
  GroqApiException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  /// Whether the caller should retry with the next key.
  bool get isRetriable => false;

  @override
  String toString() => 'GroqApiException($statusCode): $body';
}

/// 429 — rate-limited, plus **402 / 408** (quota / capacity) when Groq returns them.
/// Retry with the next API key when the pool has more than one key.
class GroqRateLimitException extends GroqApiException {
  GroqRateLimitException(super.statusCode, super.body);

  @override
  bool get isRetriable => true;

  @override
  String toString() => 'GroqRateLimitException($statusCode): $body';
}

/// 401 / 403 — bad or revoked key. Skip this key and try the next.
class GroqAuthException extends GroqApiException {
  GroqAuthException(super.statusCode, super.body);

  @override
  bool get isRetriable => true; // retriable with a *different* key

  @override
  String toString() => 'GroqAuthException($statusCode): $body';
}

/// 500+ — server-side error. Retry with the next key.
class GroqServerException extends GroqApiException {
  GroqServerException(super.statusCode, super.body);

  @override
  bool get isRetriable => true;

  @override
  String toString() => 'GroqServerException($statusCode): $body';
}

/// 4xx (other than 401/403/429) — likely a bad request; do NOT retry.
class GroqClientException extends GroqApiException {
  GroqClientException(super.statusCode, super.body);

  @override
  bool get isRetriable => false;

  @override
  String toString() => 'GroqClientException($statusCode): $body';
}
