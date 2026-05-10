import '../../domain/models/auth_session.dart';
import '../../domain/models/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../datasources/auth_session_manager.dart';
import '../datasources/browser_oauth_service.dart';
import '../utils/jwt_utils.dart';

class AuthRepositoryImpl implements AuthRepository {
  final BrowserOAuthService _browserOAuthService;
  final AuthRemoteDataSource _remote;
  final AuthSessionManager _sessionManager;

  const AuthRepositoryImpl({
    required BrowserOAuthService browserOAuthService,
    required AuthRemoteDataSource remote,
    required AuthSessionManager sessionManager,
  }) : _browserOAuthService = browserOAuthService,
       _remote = remote,
       _sessionManager = sessionManager;

  @override
  Future<AuthSession> signInWithGoogle() async {
    final callback = await _browserOAuthService.signInWithGoogle();
    final user = await _resolveUser(
      accessToken: callback.accessToken,
      callbackUser: callback.user,
    );
    final session = AuthSession(
      accessToken: callback.accessToken,
      refreshToken: callback.refreshToken,
      user: user,
    );
    await _sessionManager.persistSession(session);
    return session;
  }

  @override
  Future<AuthSession?> tryRestoreSession() async {
    final session = await _sessionManager.restoreSession();
    if (session == null || session.user.isResolved) {
      return session;
    }

    final user = await _resolveUser(
      accessToken: session.accessToken,
      callbackUser: session.user,
    );
    final hydratedSession = session.copyWith(user: user);
    await _sessionManager.persistSession(hydratedSession);
    return hydratedSession;
  }

  @override
  Future<void> logout() async {
    final session = await _sessionManager.currentSession();
    if (session != null) {
      try {
        await _remote.logout(session.refreshToken);
      } catch (_) {
        // Best-effort revocation; local sign-out still completes.
      }
    }
    await _sessionManager.clearSession();
  }

  Future<AuthUser> _resolveUser({
    required String accessToken,
    required AuthUser? callbackUser,
  }) async {
    if (callbackUser != null && callbackUser.isResolved) {
      return callbackUser;
    }

    final jwtUser = JwtUtils.tryReadUser(accessToken);
    if (jwtUser != null && jwtUser.isResolved) {
      return jwtUser;
    }

    return _remote.fetchCurrentUser(accessToken);
  }
}
