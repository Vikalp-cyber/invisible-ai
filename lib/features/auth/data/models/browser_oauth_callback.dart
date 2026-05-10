import '../../domain/models/auth_user.dart';

class BrowserOAuthCallback {
  final String accessToken;
  final String refreshToken;
  final AuthUser? user;

  const BrowserOAuthCallback({
    required this.accessToken,
    required this.refreshToken,
    this.user,
  });
}
