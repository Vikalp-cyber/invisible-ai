/// Response from `GET /api/subscription/status` (webhook is source of truth).
class SubscriptionStatus {
  const SubscriptionStatus({
    required this.premium,
    this.planType,
    this.expiresAt,
    this.message,
  });

  final bool premium;

  /// e.g. `"lifetime"` when subscribed; `null` when not.
  final String? planType;

  /// `null` for lifetime plans.
  final DateTime? expiresAt;

  final String? message;

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    final payload = _unwrap(json);
    final premiumRaw = payload['premium'];
    final expiresRaw = payload['expiresAt'] ?? payload['expires_at'];

    DateTime? expiresAt;
    if (expiresRaw is String && expiresRaw.isNotEmpty) {
      expiresAt = DateTime.tryParse(expiresRaw);
    }

    return SubscriptionStatus(
      premium: premiumRaw == true ||
          premiumRaw == 1 ||
          (premiumRaw is String && premiumRaw.toLowerCase() == 'true'),
      planType: (payload['planType'] ?? payload['plan_type'] ?? payload['plan'])
          ?.toString()
          .trim(),
      expiresAt: expiresAt,
      message: (payload['message'] as String?)?.trim(),
    );
  }

  static Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    final nested = json['data'];
    if (nested is Map<String, dynamic>) {
      return nested;
    }
    if (nested is Map) {
      return nested.cast<String, dynamic>();
    }
    return json;
  }
}
