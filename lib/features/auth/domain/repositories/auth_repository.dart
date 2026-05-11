import '../models/auth_session.dart';

abstract class AuthRepository {
  Future<AuthSession> signInWithGoogle();
  Future<void> cancelSignIn();
  Future<AuthSession?> tryRestoreSession();
  Future<void> logout();
}
