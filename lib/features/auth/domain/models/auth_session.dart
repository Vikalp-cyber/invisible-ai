import 'auth_user.dart';

class AuthSession {
  final String accessToken;
  final String refreshToken;
  final AuthUser user;

  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken:
          json['accessToken']?.toString() ??
          json['access_token']?.toString() ??
          json['token']?.toString() ??
          '',
      refreshToken:
          json['refreshToken']?.toString() ??
          json['refresh_token']?.toString() ??
          '',
      user: AuthUser.fromJson(
        (json['user'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
    );
  }

  bool get hasTokens => accessToken.isNotEmpty && refreshToken.isNotEmpty;

  AuthSession copyWith({
    String? accessToken,
    String? refreshToken,
    AuthUser? user,
  }) {
    return AuthSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      user: user ?? this.user,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'user': user.toJson(),
    };
  }
}
