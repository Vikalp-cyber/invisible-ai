import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../datasources/auth_session_manager.dart';
import '../datasources/browser_oauth_service.dart';
import '../datasources/token_storage.dart';
import '../models/desktop_oauth_config.dart';
import '../repositories/auth_repository_impl.dart';

final flutterSecureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  final secureStorage = ref.watch(flutterSecureStorageProvider);
  final tokenStorage = TokenStorage(secureStorage);
  ref.onDispose(tokenStorage.dispose);
  return tokenStorage;
});

final desktopOAuthConfigProvider = Provider<DesktopOAuthConfig>((ref) {
  return DesktopOAuthConfig.fromEnvironment();
});

final authApiDioProvider = Provider<Dio>((ref) {
  final config = ref.watch(desktopOAuthConfigProvider);
  return Dio(
    BaseOptions(
      baseUrl: config.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ),
  );
});

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(
    ref.watch(authApiDioProvider),
    ref.watch(desktopOAuthConfigProvider),
  );
});

final browserOAuthServiceProvider = Provider<BrowserOAuthService>((ref) {
  return BrowserOAuthService(ref.watch(desktopOAuthConfigProvider));
});

final authSessionManagerProvider = Provider<AuthSessionManager>((ref) {
  return AuthSessionManager(
    tokenStorage: ref.watch(tokenStorageProvider),
    remote: ref.watch(authRemoteDataSourceProvider),
    config: ref.watch(desktopOAuthConfigProvider),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    browserOAuthService: ref.watch(browserOAuthServiceProvider),
    remote: ref.watch(authRemoteDataSourceProvider),
    sessionManager: ref.watch(authSessionManagerProvider),
  );
});
