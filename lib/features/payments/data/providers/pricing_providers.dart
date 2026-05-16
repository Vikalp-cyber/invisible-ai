import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_provider.dart';
import '../../domain/models/pricing_plan.dart';
import '../pricing_repository.dart';

final pricingRepositoryProvider = Provider<PricingRepository>((ref) {
  return PricingRepository(ref.watch(dioProvider));
});

/// Public catalog from `GET /api/pricing/plans`.
final pricingPlansProvider = FutureProvider<List<PricingPlan>>((ref) async {
  return ref.read(pricingRepositoryProvider).fetchPlans();
});

/// Default checkout plan: active `lifetime`, else first active plan.
final lifetimePricingPlanProvider = Provider<PricingPlan?>((ref) {
  final plansAsync = ref.watch(pricingPlansProvider);
  return plansAsync.maybeWhen(
    data: (plans) => _pickLifetimePlan(plans),
    orElse: () => null,
  );
});

PricingPlan? _pickLifetimePlan(List<PricingPlan> plans) {
  final active = plans.where((p) => p.isActive).toList();
  if (active.isEmpty && plans.isNotEmpty) {
    return plans.first;
  }
  for (final plan in active) {
    if (plan.planType == AppConstants.premiumPlanType) {
      return plan;
    }
  }
  return active.isNotEmpty ? active.first : null;
}
