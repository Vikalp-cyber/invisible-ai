import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import 'subscription_provider.dart';

/// Whether the **current signed-in user** has premium access.
///
/// Source of truth: `GET /api/subscription/status` → `premium: true` only.
/// Does not use global SharedPreferences (that leaked premium across accounts).
final isPremiumProvider = Provider<bool>((ref) {
  final authed = ref.watch(authProvider.select((a) => a.isAuthenticated));
  if (!authed) {
    return false;
  }

  final subscription = ref.watch(subscriptionStatusProvider);
  return subscription.maybeWhen(
    data: (status) => status?.premium == true,
    orElse: () => false,
  );
});
