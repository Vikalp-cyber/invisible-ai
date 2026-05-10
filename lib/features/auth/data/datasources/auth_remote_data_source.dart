import 'package:dio/dio.dart';

import '../../../../core/network/network_request_flags.dart';
import '../../domain/models/auth_exception.dart';
import '../../domain/models/auth_session.dart';
import '../../domain/models/auth_user.dart';
import '../models/desktop_oauth_config.dart';

class AuthRemoteDataSource {
  final Dio _dio;
  final DesktopOAuthConfig _config;

  const AuthRemoteDataSource(this._dio, this._config);

  Future<AuthSession> refreshSession({
    required String refreshToken,
    required AuthUser fallbackUser,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _config.refreshPath,
        data: {'refreshToken': refreshToken},
        options: Options(extra: {skipAuthRequestFlag: true}),
      );

      return _parseSessionResponse(response.data, fallbackUser: fallbackUser);
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      throw AuthException(
        _networkMessage('Could not refresh the session.', error),
        code: statusCode == 400 || statusCode == 401 || statusCode == 403
            ? 'unauthorized'
            : 'network',
      );
    }
  }

  Future<AuthUser> fetchCurrentUser(String accessToken) async {
    if (_config.mePath.isEmpty) {
      throw const AuthException(
        'The backend did not provide a user profile and AUTH_ME_PATH is not configured.',
        code: 'profile_unavailable',
      );
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _config.mePath,
        options: Options(
          headers: {'Authorization': 'Bearer $accessToken'},
          extra: {skipAuthRequestFlag: true},
        ),
      );

      final payload = _unwrapPayload(response.data);
      final user =
          _extractUser(payload) ??
          _extractUser(_asMap(payload['user'])) ??
          _extractUser(_asMap(payload['profile']));

      if (user == null || !user.isResolved) {
        throw const AuthException(
          'The backend did not return a usable user profile for this session.',
          code: 'profile_unavailable',
        );
      }
      return user;
    } on DioException catch (error) {
      throw AuthException(
        _networkMessage('Could not load the signed-in user profile.', error),
        code: 'network',
      );
    }
  }

  Future<void> logout(String refreshToken) async {
    if (_config.logoutPath.isEmpty) {
      return;
    }

    try {
      await _dio.post<void>(
        _config.logoutPath,
        data: {'refreshToken': refreshToken},
        options: Options(extra: {skipAuthRequestFlag: true}),
      );
    } on DioException catch (error) {
      throw AuthException(
        _networkMessage('Could not notify the backend about logout.', error),
        code: 'network',
      );
    }
  }

  AuthSession _parseSessionResponse(
    Map<String, dynamic>? responseBody, {
    required AuthUser fallbackUser,
  }) {
    final payload = _unwrapPayload(responseBody);
    final tokenPayload = _asMap(payload['tokens']) ?? payload;

    final accessToken = _firstNonEmpty(tokenPayload, const [
      'accessToken',
      'access_token',
      'token',
    ]);
    final refreshToken = _firstNonEmpty(tokenPayload, const [
      'refreshToken',
      'refresh_token',
    ]);
    final user =
        _extractUser(payload) ?? _extractUser(tokenPayload) ?? fallbackUser;

    if (accessToken == null || refreshToken == null) {
      throw const AuthException(
        'The auth response did not include both access and refresh tokens.',
        code: 'invalid_session',
      );
    }

    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: user,
    );
  }

  Map<String, dynamic> _unwrapPayload(Map<String, dynamic>? responseBody) {
    if (responseBody == null) {
      throw const AuthException(
        'The auth endpoint returned an empty response.',
        code: 'invalid_session',
      );
    }

    var payload = responseBody;
    while (true) {
      final nested = _asMap(payload['data']) ?? _asMap(payload['session']);
      if (nested == null) {
        return payload;
      }
      payload = nested;
    }
  }

  AuthUser? _extractUser(Map<String, dynamic>? payload) {
    if (payload == null) {
      return null;
    }

    final nestedUser = _asMap(payload['user']) ?? _asMap(payload['profile']);
    if (nestedUser != null) {
      final user = AuthUser.fromJson(nestedUser);
      return user.isResolved ? user : null;
    }

    final user = AuthUser.fromJson(payload);
    return user.isResolved ? user : null;
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    return null;
  }

  String? _firstNonEmpty(Map<String, dynamic> payload, List<String> keys) {
    for (final key in keys) {
      final value = payload[key]?.toString();
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  String _networkMessage(String prefix, DioException error) {
    final responseMessage = _extractResponseMessage(error.response?.data);
    if (responseMessage != null) {
      return '$prefix $responseMessage';
    }

    final statusCode = error.response?.statusCode;
    if (statusCode != null) {
      return '$prefix Server returned HTTP $statusCode.';
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '$prefix The request timed out.';
      case DioExceptionType.connectionError:
        return '$prefix Could not reach the backend.';
      default:
        return '$prefix ${error.message ?? 'Unexpected network error.'}';
    }
  }

  String? _extractResponseMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data['message']?.toString() ??
          data['error']?.toString() ??
          _extractResponseMessage(data['data']);
    }
    if (data is Map) {
      return _extractResponseMessage(data.cast<String, dynamic>());
    }
    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }
    return null;
  }
}
