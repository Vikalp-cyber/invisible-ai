import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/models/pricing_plan.dart';
import '../../data/providers/pricing_providers.dart';
import '../providers/payment_flow_provider.dart';
import '../providers/premium_provider.dart';

/// Premium upgrade card for Settings — public pricing + browser Razorpay checkout.
class UpgradeCard extends ConsumerStatefulWidget {
  const UpgradeCard({super.key});

  @override
  ConsumerState<UpgradeCard> createState() => _UpgradeCardState();
}

class _UpgradeCardState extends ConsumerState<UpgradeCard> {
  bool _showSuccessBurst = false;

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(isPremiumProvider);
    final flow = ref.watch(paymentFlowProvider);
    final plansAsync = ref.watch(pricingPlansProvider);
    final lifetimePlan = ref.watch(lifetimePricingPlanProvider);

    ref.listen(paymentFlowProvider, (prev, next) {
      if (next.phase == PaymentFlowPhase.success &&
          prev?.phase != PaymentFlowPhase.success) {
        setState(() => _showSuccessBurst = true);
        _showSuccessDialog(context, next.successMessage);
        Future<void>.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => _showSuccessBurst = false);
          }
        });
      }
    });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder, width: 0.8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.secondary.withValues(alpha: 0.08),
            AppColors.surface.withValues(alpha: 0.6),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isPremium ? Icons.verified_rounded : Icons.workspace_premium_rounded,
                  color: isPremium ? AppColors.success : AppColors.primary,
                  size: 28,
                ),
              )
                  .animate(target: _showSuccessBurst ? 1 : 0)
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.15, 1.15),
                    duration: 400.ms,
                    curve: Curves.elasticOut,
                  ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isPremium
                                ? 'Flowdesk Premium'
                                : (lifetimePlan?.displayName ?? 'Upgrade to Premium'),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isPremium) ...[
                          const SizedBox(width: 8),
                          _PremiumBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPremium
                          ? 'You have full access to premium features.'
                          : (lifetimePlan?.description.isNotEmpty == true
                                ? lifetimePlan!.description
                                : 'Pay securely in your browser — we confirm via your account.'),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          plansAsync.when(
            data: (plans) {
              if (lifetimePlan == null) {
                return const _StatusBanner(
                  message: 'No premium plans are available right now.',
                  color: AppColors.warning,
                  icon: Icons.info_outline_rounded,
                );
              }
              return _PricingRow(plan: lifetimePlan);
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 2),
            ),
            error: (e, _) => _StatusBanner(
              message: 'Could not load pricing: $e',
              color: AppColors.error,
              icon: Icons.cloud_off_rounded,
            ),
          ),
          const SizedBox(height: 12),
          if (lifetimePlan != null && lifetimePlan.tokensGranted > 0)
            _FeatureRow(
              text:
                  '${_formatTokens(lifetimePlan.tokensGranted)} tokens included',
            ),
          const _FeatureRow(text: 'Interview & speaker copilot'),
          const _FeatureRow(text: 'Priority Groq model access'),
          const SizedBox(height: 16),
          if (flow.successMessage != null &&
              flow.phase == PaymentFlowPhase.success) ...[
            _StatusBanner(
              message: flow.successMessage!,
              color: AppColors.success,
              icon: Icons.check_circle_rounded,
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
            const SizedBox(height: 12),
          ],
          if (flow.errorMessage != null &&
              flow.phase != PaymentFlowPhase.idle) ...[
            _StatusBanner(
              message: flow.errorMessage!,
              color: _errorColor(flow.phase),
              icon: Icons.info_outline_rounded,
            ),
            const SizedBox(height: 12),
          ],
          if (!isPremium) ...[
            if (flow.isBusy) ...[
              _ProcessingRow(phase: flow.phase),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: flow.isBusy || lifetimePlan == null
                    ? null
                    : () => ref
                        .read(paymentFlowProvider.notifier)
                        .startUpgrade(planType: lifetimePlan.planType),
                icon: flow.isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textOnPrimary,
                        ),
                      )
                    : const Icon(Icons.open_in_browser_rounded),
                label: Text(
                  flow.isBusy
                      ? _busyLabel(flow.phase)
                      : _upgradeButtonLabel(lifetimePlan),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textOnPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            if (flow.isBusy) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () =>
                      ref.read(paymentFlowProvider.notifier).cancelUpgrade(),
                  child: const Text('Cancel waiting'),
                ),
              ),
            ],
            if (flow.phase == PaymentFlowPhase.failed ||
                flow.phase == PaymentFlowPhase.timedOut) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: flow.isBusy || lifetimePlan == null
                    ? null
                    : () => ref
                        .read(paymentFlowProvider.notifier)
                        .startUpgrade(planType: lifetimePlan.planType),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ] else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_rounded, color: AppColors.success, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Premium active',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _upgradeButtonLabel(PricingPlan? plan) {
    if (plan == null) {
      return 'Upgrade';
    }
    final price = plan.amountRupees > 0
        ? plan.amountRupees
        : plan.amountPaise / 100;
    final suffix = plan.planType == 'lifetime' ? 'lifetime' : plan.planType;
    return 'Upgrade — ₹${price.toStringAsFixed(price == price.roundToDouble() ? 0 : 2)} $suffix';
  }

  static String _formatTokens(int tokens) {
    if (tokens >= 1000000) {
      return '${(tokens / 1000000).toStringAsFixed(1)}M';
    }
    if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(0)}K';
    }
    return tokens.toString();
  }

  static Color _errorColor(PaymentFlowPhase phase) {
    return switch (phase) {
      PaymentFlowPhase.cancelled => AppColors.warning,
      PaymentFlowPhase.timedOut => AppColors.warning,
      _ => AppColors.error,
    };
  }

  void _showSuccessDialog(BuildContext context, String? message) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.celebration_rounded, color: AppColors.success),
            SizedBox(width: 10),
            Text('Premium unlocked', style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        content: Text(
          message ?? 'Your premium features are now active.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
      ),
      child: const Text(
        'PRO',
        style: TextStyle(
          color: AppColors.success,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _PricingRow extends StatelessWidget {
  const _PricingRow({required this.plan});

  final PricingPlan plan;

  @override
  Widget build(BuildContext context) {
    final price = plan.amountRupees > 0
        ? plan.amountRupees
        : plan.amountPaise / 100;
    final priceLabel = price == price.roundToDouble()
        ? price.toStringAsFixed(0)
        : price.toStringAsFixed(2);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.backgroundDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              plan.displayName,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
          Text(
            '₹$priceLabel',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            plan.planType == 'lifetime' ? ' · lifetime' : ' · ${plan.planType}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

String _busyLabel(PaymentFlowPhase phase) {
  return switch (phase) {
    PaymentFlowPhase.creatingLink => 'Creating payment link…',
    PaymentFlowPhase.openingBrowser => 'Opening browser…',
    PaymentFlowPhase.pollingSubscription =>
      'Complete payment in your browser…',
    _ => 'Processing…',
  };
}

class _ProcessingRow extends StatelessWidget {
  const _ProcessingRow({required this.phase});

  final PaymentFlowPhase phase;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
        )
            .animate(onPlay: (c) => c.repeat())
            .shimmer(duration: 1200.ms, color: AppColors.primary.withValues(alpha: 0.3)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _busyLabel(phase),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.check_rounded, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.message,
    required this.color,
    required this.icon,
  });

  final String message;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
