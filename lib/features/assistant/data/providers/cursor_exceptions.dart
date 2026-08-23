/// Cursor Cloud Agents API errors surfaced for key rotation / retry logic.
sealed class CursorApiException implements Exception {
  const CursorApiException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  bool get isRetriable =>
      statusCode == 429 || statusCode == 402 || statusCode == 408 || statusCode >= 500;

  @override
  String toString() => 'Cursor API $statusCode: $body';
}

final class CursorAuthException extends CursorApiException {
  const CursorAuthException(super.statusCode, super.body);
}

final class CursorRateLimitException extends CursorApiException {
  const CursorRateLimitException(super.statusCode, super.body);
}

final class CursorServerException extends CursorApiException {
  const CursorServerException(super.statusCode, super.body);
}

final class CursorClientException extends CursorApiException {
  const CursorClientException(super.statusCode, super.body);
}

CursorApiException cursorExceptionForStatus(int code, String body) {
  if (code == 429 || code == 402 || code == 408) {
    return CursorRateLimitException(code, body);
  }
  if (code == 401 || code == 403) {
    return CursorAuthException(code, body);
  }
  if (code >= 500) {
    return CursorServerException(code, body);
  }
  return CursorClientException(code, body);
}
