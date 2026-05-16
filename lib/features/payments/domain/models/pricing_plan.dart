/// Single plan from `GET /api/pricing/plans` (public).
class PricingPlan {
  const PricingPlan({
    required this.planType,
    required this.displayName,
    required this.description,
    required this.amountPaise,
    required this.amountRupees,
    required this.currency,
    required this.tokensGranted,
    required this.isActive,
    this.updatedAt,
  });

  final String planType;
  final String displayName;
  final String description;
  final int amountPaise;
  final double amountRupees;
  final String currency;
  final int tokensGranted;
  final bool isActive;
  final DateTime? updatedAt;

  factory PricingPlan.fromJson(Map<String, dynamic> json) {
    final amountPaiseRaw = json['amountPaise'] ?? json['amount_paise'];
    final amountRupeesRaw = json['amountRupees'] ?? json['amount_rupees'];

    return PricingPlan(
      planType: (json['planType'] ?? json['plan_type'] ?? '').toString(),
      displayName:
          (json['displayName'] ?? json['display_name'] ?? 'Premium').toString(),
      description: (json['description'] as String?) ?? '',
      amountPaise: amountPaiseRaw is int
          ? amountPaiseRaw
          : (amountPaiseRaw is num ? amountPaiseRaw.toInt() : 0),
      amountRupees: amountRupeesRaw is num
          ? amountRupeesRaw.toDouble()
          : double.tryParse(amountRupeesRaw?.toString() ?? '') ?? 0,
      currency: (json['currency'] as String?)?.trim() ?? 'INR',
      tokensGranted: _parseInt(json['tokensGranted'] ?? json['tokens_granted']),
      isActive: json['isActive'] == true ||
          json['is_active'] == true ||
          json['isActive'] == 1,
      updatedAt: _parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

/// Response wrapper for `GET /api/pricing/plans`.
class PricingPlansResponse {
  const PricingPlansResponse({required this.plans});

  final List<PricingPlan> plans;

  factory PricingPlansResponse.fromJson(Map<String, dynamic> json) {
    final payload = _unwrap(json);
    final raw = payload['plans'];
    final plans = <PricingPlan>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          plans.add(PricingPlan.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return PricingPlansResponse(plans: plans);
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
