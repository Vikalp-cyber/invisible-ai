class AuthUser {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;

  const AuthUser({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final email =
        json['email']?.toString() ??
        json['preferred_username']?.toString() ??
        '';
    return AuthUser(
      id:
          json['id']?.toString() ??
          json['sub']?.toString() ??
          json['userId']?.toString() ??
          email,
      email: email,
      displayName: json['displayName']?.toString() ?? json['name']?.toString(),
      photoUrl:
          json['photoUrl']?.toString() ??
          json['avatarUrl']?.toString() ??
          json['picture']?.toString(),
    );
  }

  bool get isResolved => id.isNotEmpty || email.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
    };
  }
}
