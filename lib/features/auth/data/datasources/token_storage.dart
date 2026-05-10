import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/models/auth_session.dart';
import '../../domain/models/auth_user.dart';

class TokenStorage {
  static const _accessTokenKey = 'auth_access_token';
  static const _refreshTokenKey = 'auth_refresh_token';
  static const _userJsonKey = 'auth_user_json';

  final FlutterSecureStorage _storage;
  final StreamController<AuthSession?> _sessionChanges =
      StreamController<AuthSession?>.broadcast();

  TokenStorage(this._storage);

  Stream<AuthSession?> get sessionChanges => _sessionChanges.stream;

  Future<void> saveSession(AuthSession session) async {
    await _storage.write(key: _accessTokenKey, value: session.accessToken);
    await _storage.write(key: _refreshTokenKey, value: session.refreshToken);
    await _storage.write(
      key: _userJsonKey,
      value: jsonEncode(session.user.toJson()),
    );
    _sessionChanges.add(session);
  }

  Future<AuthSession?> readSession() async {
    final accessToken = await getAccessToken();
    final refreshToken = await getRefreshToken();
    final userJson = await getUserJson();

    if (accessToken == null || refreshToken == null || userJson == null) {
      return null;
    }

    final user = _decodeStoredUser(userJson);
    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: user,
    );
  }

  Future<String?> getAccessToken() => _storage.read(key: _accessTokenKey);
  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);
  Future<String?> getUserJson() => _storage.read(key: _userJsonKey);

  Future<void> clearSession() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userJsonKey);
    _sessionChanges.add(null);
  }

  void dispose() {
    _sessionChanges.close();
  }

  AuthUser _decodeStoredUser(String userJson) {
    try {
      final decoded = jsonDecode(userJson);
      final user = AuthUser.fromJson(
        decoded is Map<String, dynamic>
            ? decoded
            : (decoded as Map).cast<String, dynamic>(),
      );
      if (user.isResolved) {
        return user;
      }
    } catch (_) {
      // Fallback to an empty user when older stored data is malformed.
    }
    return const AuthUser(id: '', email: '');
  }
}
