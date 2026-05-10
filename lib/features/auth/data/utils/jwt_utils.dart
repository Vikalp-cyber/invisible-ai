import 'dart:convert';

import '../../domain/models/auth_user.dart';

class JwtUtils {
  JwtUtils._();

  static Map<String, dynamic>? tryDecodePayload(String token) {
    final parts = token.split('.');
    if (parts.length < 2) {
      return null;
    }

    try {
      final normalized = base64Url.normalize(parts[1]);
      final payload = utf8.decode(base64Url.decode(normalized));
      final json = jsonDecode(payload);
      if (json is Map<String, dynamic>) {
        return json;
      }
      if (json is Map) {
        return json.cast<String, dynamic>();
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static DateTime? readExpiry(String token) {
    final payload = tryDecodePayload(token);
    final expValue = payload?['exp'];
    final seconds = expValue is num
        ? expValue.toInt()
        : int.tryParse(expValue?.toString() ?? '');
    if (seconds == null) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  static bool isExpiringSoon(
    String token, {
    Duration skew = const Duration(seconds: 60),
  }) {
    if (token.isEmpty) {
      return true;
    }

    final expiry = readExpiry(token);
    if (expiry == null) {
      return false;
    }

    return expiry.isBefore(DateTime.now().toUtc().add(skew));
  }

  static AuthUser? tryReadUser(String token) {
    final payload = tryDecodePayload(token);
    if (payload == null) {
      return null;
    }

    final user = AuthUser.fromJson({
      'id': payload['sub'] ?? payload['id'] ?? payload['userId'],
      'email': payload['email'] ?? payload['preferred_username'],
      'displayName': payload['name'] ?? payload['displayName'],
      'photoUrl': payload['picture'] ?? payload['photoUrl'],
    });

    return user.isResolved ? user : null;
  }
}
