class TokenUsage {
  final String userId;
  final String email;
  final String name;
  final int tokensUsed;
  final int tokenLimit;
  final int tokensRemaining;
  final bool isActive;
  final int totalPaidPaise;
  final num totalPaidRupees;

  const TokenUsage({
    required this.userId,
    required this.email,
    required this.name,
    required this.tokensUsed,
    required this.tokenLimit,
    required this.tokensRemaining,
    required this.isActive,
    required this.totalPaidPaise,
    required this.totalPaidRupees,
  });

  factory TokenUsage.fromJson(Map<String, dynamic> json) {
    return TokenUsage(
      userId: json['userId'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      tokensUsed: json['tokensUsed'] as int? ?? 0,
      tokenLimit: json['tokenLimit'] as int? ?? 10000,
      tokensRemaining: json['tokensRemaining'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      totalPaidPaise: json['totalPaidPaise'] as int? ?? 0,
      totalPaidRupees: json['totalPaidRupees'] as num? ?? 0,
    );
  }

  TokenUsage copyWith({
    String? userId,
    String? email,
    String? name,
    int? tokensUsed,
    int? tokenLimit,
    int? tokensRemaining,
    bool? isActive,
    int? totalPaidPaise,
    num? totalPaidRupees,
  }) {
    return TokenUsage(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      name: name ?? this.name,
      tokensUsed: tokensUsed ?? this.tokensUsed,
      tokenLimit: tokenLimit ?? this.tokenLimit,
      tokensRemaining: tokensRemaining ?? this.tokensRemaining,
      isActive: isActive ?? this.isActive,
      totalPaidPaise: totalPaidPaise ?? this.totalPaidPaise,
      totalPaidRupees: totalPaidRupees ?? this.totalPaidRupees,
    );
  }
}
