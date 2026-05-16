/// Response from `POST /api/payments/create-link`.
class PaymentLink {
  const PaymentLink({
    required this.paymentLink,
    required this.paymentId,
    this.expiresAt,
  });

  /// Razorpay Payment Link URL (open in external browser).
  final String paymentLink;

  /// Internal backend payment record id (for support / webhook correlation).
  final String paymentId;

  final DateTime? expiresAt;

  factory PaymentLink.fromJson(Map<String, dynamic> json) {
    final payload = _unwrap(json);
    final link = (payload['paymentLink'] ??
            payload['payment_link'] ??
            payload['paymentUrl'] ??
            payload['payment_url'] ??
            payload['shortUrl'] ??
            '')
        .toString()
        .trim();

    final expiresRaw = payload['expiresAt'] ?? payload['expires_at'];
    DateTime? expiresAt;
    if (expiresRaw is String && expiresRaw.isNotEmpty) {
      expiresAt = DateTime.tryParse(expiresRaw);
    }

    return PaymentLink(
      paymentLink: link,
      paymentId: (payload['paymentId'] ?? payload['payment_id'] ?? '').toString(),
      expiresAt: expiresAt,
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
