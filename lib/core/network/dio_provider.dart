import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/datasources/auth_session_manager.dart';
import '../../features/auth/data/providers/auth_data_providers.dart';
import 'network_request_flags.dart';

class AuthTokenInterceptor extends QueuedInterceptor {
  final AuthSessionManager _sessionManager;
  late final Dio _dio;

  AuthTokenInterceptor(this._sessionManager);

  void attach(Dio dio) {
    _dio = dio;
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[skipAuthRequestFlag] == true) {
      handler.next(options);
      return;
    }

    try {
      final token = await _sessionManager.getValidAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    } catch (error) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final requestOptions = err.requestOptions;
    final shouldRetry =
        requestOptions.extra[skipAuthRequestFlag] != true &&
        requestOptions.extra[authRetryAttemptedFlag] != true &&
        err.response?.statusCode == 401;

    if (!shouldRetry) {
      handler.next(err);
      return;
    }

    try {
      final refreshedSession = await _sessionManager.refreshSession();
      if (refreshedSession == null || refreshedSession.accessToken.isEmpty) {
        handler.next(err);
        return;
      }

      final headers = Map<String, dynamic>.from(requestOptions.headers)
        ..['Authorization'] = 'Bearer ${refreshedSession.accessToken}';
      final extra = Map<String, dynamic>.from(requestOptions.extra)
        ..[authRetryAttemptedFlag] = true;
      final retryResponse = await _dio.fetch<dynamic>(
        requestOptions.copyWith(headers: headers, extra: extra),
      );
      handler.resolve(retryResponse);
    } catch (_) {
      handler.next(err);
    }
  }
}

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(desktopOAuthConfigProvider);
  final sessionManager = ref.watch(authSessionManagerProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: config.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ),
  );
  final interceptor = AuthTokenInterceptor(sessionManager)..attach(dio);
  dio.interceptors.add(interceptor);
  return dio;
});
