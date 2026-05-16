import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/common_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/subscription_status.dart';

/// Latest subscription status from `GET /api/subscription/status`.
///
/// Re-fetches when the signed-in user id changes (logout / switch account).
final subscriptionStatusProvider =
    FutureProvider.autoDispose<SubscriptionStatus?>((ref) async {
  final authed = ref.watch(authProvider.select((a) => a.isAuthenticated));
  if (!authed) {
    return null;
  }

  // New fetch per account — avoids showing the previous user's subscription.
  ref.watch(
    authProvider.select((a) => a.session?.user.id ?? a.session?.user.email),
  );

  return ref.read(paymentServiceProvider).fetchSubscriptionStatus();
});
