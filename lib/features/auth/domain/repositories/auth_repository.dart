import '../models/auth_session.dart';

abstract class AuthRepository {
  Future<AuthSession> signInWithGoogle();
  Future<AuthSession?> tryRestoreSession();
  Future<void> logout();
}
