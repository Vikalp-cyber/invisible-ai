import '../../domain/models/auth_exception.dart';
import '../../domain/models/auth_session.dart';
import '../models/desktop_oauth_config.dart';
import '../utils/jwt_utils.dart';
import 'auth_remote_data_source.dart';
import 'token_storage.dart';

class AuthSessionManager {
  final TokenStorage _tokenStorage;
  final AuthRemoteDataSource _remote;
  final DesktopOAuthConfig _config;

  Future<AuthSession?>? _refreshInFlight;

  AuthSessionManager({
    required TokenStorage tokenStorage,
    required AuthRemoteDataSource remote,
    required DesktopOAuthConfig config,
  }) : _tokenStorage = tokenStorage,
       _remote = remote,
       _config = config;

  Future<AuthSession?> currentSession() => _tokenStorage.readSession();

  Future<AuthSession?> restoreSession() async {
    final session = await _tokenStorage.readSession();
    if (session == null) {
      return null;
    }

    if (!JwtUtils.isExpiringSoon(
      session.accessToken,
      skew: _config.tokenRefreshSkew,
    )) {
      return session;
    }

    return refreshSession(fallbackSession: session);
  }

  Future<String?> getValidAccessToken() async {
    final session = await _tokenStorage.readSession();
    if (session == null) {
      return null;
    }

    if (!JwtUtils.isExpiringSoon(
      session.accessToken,
      skew: _config.tokenRefreshSkew,
    )) {
      return session.accessToken;
    }

    final refreshed = await refreshSession(fallbackSession: session);
    return refreshed?.accessToken;
  }

  Future<void> persistSession(AuthSession session) {
    return _tokenStorage.saveSession(session);
  }

  Future<void> clearSession() => _tokenStorage.clearSession();

  Future<AuthSession?> refreshSession({AuthSession? fallbackSession}) {
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final refreshFuture = _performRefresh(fallbackSession);
    _refreshInFlight = refreshFuture.whenComplete(() {
      _refreshInFlight = null;
    });
    return _refreshInFlight!;
  }

  Future<AuthSession?> _performRefresh(AuthSession? fallbackSession) async {
    final session = fallbackSession ?? await _tokenStorage.readSession();
    if (session == null) {
      return null;
    }

    if (session.refreshToken.isEmpty) {
      await clearSession();
      throw const AuthException(
        'The saved session does not include a refresh token.',
      );
    }

    try {
      final refreshed = await _remote.refreshSession(
        refreshToken: session.refreshToken,
        fallbackUser: session.user,
      );
      await _tokenStorage.saveSession(refreshed);
      return refreshed;
    } on AuthException catch (error) {
      if (error.code == 'unauthorized' || error.code == 'invalid_session') {
        await clearSession();
      }
      rethrow;
    }
  }
}
