import 'package:dio/dio.dart';

/// Typed failures from `GET /api/client-config` (and legacy Groq-only route).
class ClientConfigException implements Exception {
  ClientConfigException(this.message, {this.httpStatus, this.bodyCode});

  final String message;
  final int? httpStatus;
  final String? bodyCode;

  @override
  String toString() => message;
}

/// HTTP 503 or empty Groq `keys` — admin must add keys.
class ClientConfigMissingGroqKeysException extends ClientConfigException {
  ClientConfigMissingGroqKeysException([String? message])
      : super(
          message ??
              'Groq is not configured on the server. An admin must add API keys.',
          httpStatus: 503,
          bodyCode: 'MISSING_GROQ_KEYS',
        );
}

/// HTTP 403 with account / quota codes from the backend.
class ClientConfigAccountException extends ClientConfigException {
  ClientConfigAccountException(super.message, {super.httpStatus, super.bodyCode});
}

/// Session invalid after refresh (HTTP 401).
class ClientConfigUnauthorizedException extends ClientConfigException {
  ClientConfigUnauthorizedException([String? message])
      : super(
          message ?? 'Session expired. Please sign in again.',
          httpStatus: 401,
        );
}

String? _parseBodyCode(dynamic data) {
  if (data is Map) {
    final c = data['code'];
    if (c is String) {
      return c;
    }
  }
  return null;
}

/// Maps [DioException] from client-config to a typed [ClientConfigException] when possible.
ClientConfigException? clientConfigExceptionFromDio(DioException e) {
  final status = e.response?.statusCode;
  final data = e.response?.data;
  final code = _parseBodyCode(data);

  if (status == 401) {
    return ClientConfigUnauthorizedException();
  }
  if (status == 403) {
    if (code == 'ACCOUNT_INACTIVE' || code == 'TOKEN_LIMIT_EXCEEDED') {
      return ClientConfigAccountException(
        code == 'ACCOUNT_INACTIVE'
            ? 'Your account is inactive. Please renew or contact support.'
            : 'Token quota exceeded. Please upgrade to continue.',
        httpStatus: 403,
        bodyCode: code,
      );
    }
    return ClientConfigAccountException(
      'Request was denied (${code ?? 'forbidden'}).',
      httpStatus: 403,
      bodyCode: code,
    );
  }
  if (status == 503 && code == 'MISSING_GROQ_KEYS') {
    return ClientConfigMissingGroqKeysException();
  }
  return null;
}
