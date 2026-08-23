import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/common_providers.dart';
import '../../../../services/payment_service.dart';
import '../../domain/models/payment_exception.dart';
import '../../../usage/presentation/providers/usage_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../assistant/data/providers/groq_config_providers.dart';
import '../../data/providers/pricing_providers.dart';
import 'subscription_provider.dart';

enum PaymentFlowPhase {
  idle,
  creatingLink,
  openingBrowser,
  pollingSubscription,
  success,
  failed,
  cancelled,
  timedOut,
}

class PaymentFlowState {
  const PaymentFlowState({
    this.phase = PaymentFlowPhase.idle,
    this.errorMessage,
    this.successMessage,
  });

  final PaymentFlowPhase phase;
  final String? errorMessage;
  final String? successMessage;

  bool get isBusy =>
      phase == PaymentFlowPhase.creatingLink ||
      phase == PaymentFlowPhase.openingBrowser ||
      phase == PaymentFlowPhase.pollingSubscription;

  PaymentFlowState copyWith({
    PaymentFlowPhase? phase,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return PaymentFlowState(
      phase: phase ?? this.phase,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class PaymentFlowNotifier extends Notifier<PaymentFlowState> {
  @override
  PaymentFlowState build() => const PaymentFlowState();

  Future<void> startUpgrade({String? planType}) async {
    if (state.isBusy) {
      return;
    }

    final plan = ref.read(lifetimePricingPlanProvider);
    final resolvedPlanType =
        planType ?? plan?.planType ?? AppConstants.premiumPlanType;

    state = state.copyWith(
      phase: PaymentFlowPhase.creatingLink,
      clearError: true,
      clearSuccess: true,
    );

    final service = ref.read(paymentServiceProvider);

    try {
      if (PaymentService.kRazorpayMock) {
        state = state.copyWith(phase: PaymentFlowPhase.pollingSubscription);
        final status =
            await service.upgradeToPremium(planType: resolvedPlanType);
        await _onPremiumConfirmed(status.message);
        return;
      }

      final link = await service.createPaymentLink(planType: resolvedPlanType);

      state = state.copyWith(phase: PaymentFlowPhase.openingBrowser);
      await service.openPaymentInBrowser(link);

      state = state.copyWith(phase: PaymentFlowPhase.pollingSubscription);
      final status = await service.waitForPremiumActivation();
      await service.applyPremiumStatus(status);

      await _onPremiumConfirmed(status.message);
    } on PremiumAlreadyActiveException catch (e) {
      await service.syncPremiumFromServer();
      await _onPremiumConfirmed(e.message);
    } on PaymentCancelledException catch (e) {
      state = state.copyWith(
        phase: PaymentFlowPhase.cancelled,
        errorMessage: e.message,
      );
    } on PaymentTimeoutException catch (e) {
      state = state.copyWith(
        phase: PaymentFlowPhase.timedOut,
        errorMessage: e.message,
      );
    } on PaymentException catch (e) {
      debugPrint('[PaymentFlow] failed: $e');
      state = state.copyWith(
        phase: PaymentFlowPhase.failed,
        errorMessage: e.message,
      );
    } catch (e, st) {
      debugPrint('[PaymentFlow] unexpected: $e\n$st');
      state = state.copyWith(
        phase: PaymentFlowPhase.failed,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _onPremiumConfirmed(String? serverMessage) async {
    await ref.read(usageProvider.notifier).refreshUsage();
    await ref.read(authProvider.notifier).refreshSession();
    await ref.read(localGroqKeysProvider.notifier).refresh();

    // Defer invalidate — [subscriptionStatusProvider] depends on [authProvider].
    Future.microtask(() {
      ref.invalidate(subscriptionStatusProvider);
    });

    state = state.copyWith(
      phase: PaymentFlowPhase.success,
      successMessage: serverMessage ??
          'Welcome to Flowdesk Premium! Your features are now unlocked.',
    );
  }

  void cancelUpgrade() {
    ref.read(paymentServiceProvider).cancelActiveUpgrade();
    state = state.copyWith(
      phase: PaymentFlowPhase.cancelled,
      errorMessage: 'Payment waiting cancelled. You can try again anytime.',
    );
  }

  void reset() {
    state = const PaymentFlowState();
  }
}

final paymentFlowProvider =
    NotifierProvider<PaymentFlowNotifier, PaymentFlowState>(
  PaymentFlowNotifier.new,
);
