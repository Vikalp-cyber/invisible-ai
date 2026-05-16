import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/app_constants.dart';
import '../features/auth/data/datasources/auth_remote_data_source.dart';
import '../features/auth/data/datasources/auth_session_manager.dart';
import '../features/payments/data/payment_repository.dart';
import '../features/payments/domain/models/payment_exception.dart';
import '../features/payments/domain/models/payment_link.dart';
import '../features/payments/domain/models/subscription_status.dart';
import 'preference_service.dart';

/// Browser-based Razorpay Payment Link flow for **Windows desktop**.
///
/// 1. `POST /api/payments/create-link` (`planType: lifetime`)
/// 2. Open `paymentLink` in external browser
/// 3. Poll `GET /api/subscription/status` until `premium: true` (webhook truth)
///
/// Never stores Razorpay secrets; never verifies payment in the client.
class PaymentService {
  PaymentService({
    required PaymentRepository repository,
    required PreferenceService preferences,
    required AuthRemoteDataSource authRemote,
    required AuthSessionManager sessionManager,
  })  : _repository = repository,
        _preferences = preferences,
        _authRemote = authRemote,
        _sessionManager = sessionManager;

  final PaymentRepository _repository;
  final PreferenceService _preferences;
  final AuthRemoteDataSource _authRemote;
  final AuthSessionManager _sessionManager;

  bool _cancelPolling = false;

  /// `dart-define=RAZORPAY_MOCK=true` skips browser; still requires server poll in prod.
  static const bool kRazorpayMock = bool.fromEnvironment(
    'RAZORPAY_MOCK',
    defaultValue: false,
  );

  void cancelActiveUpgrade() {
    _cancelPolling = true;
  }

  Future<PaymentLink> createPaymentLink({
    String planType = AppConstants.premiumPlanType,
  }) =>
      _repository.createPaymentLink(planType: planType);

  Future<void> openPaymentInBrowser(PaymentLink link) async {
    final uri = Uri.tryParse(link.paymentLink);
    if (uri == null) {
      throw PaymentException('Invalid paymentLink URL from server.');
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw PaymentCheckoutUnavailableException();
    }
    debugPrint(
      '[PaymentService] opened browser paymentId=${link.paymentId} '
      'url=${link.paymentLink}',
    );
  }

  Future<SubscriptionStatus> waitForPremiumActivation() => _pollUntilPremium();

  /// Local cache only — [status] must come from `GET /subscription/status`.
  Future<void> applyPremiumStatus(SubscriptionStatus status) =>
      _activatePremium(status);

  Future<SubscriptionStatus> upgradeToPremium({
    String planType = AppConstants.premiumPlanType,
  }) async {
    _cancelPolling = false;
    debugPrint('[PaymentService] upgradeToPremium start mock=$kRazorpayMock');

    if (kRazorpayMock) {
      await Future<void>.delayed(const Duration(seconds: 2));
      final status = const SubscriptionStatus(
        premium: true,
        planType: 'lifetime',
      );
      await _activatePremium(status);
      return status;
    }

    final link = await createPaymentLink(planType: planType);
    await openPaymentInBrowser(link);
    final status = await waitForPremiumActivation();
    await applyPremiumStatus(status);
    debugPrint('[PaymentService] upgradeToPremium success premium=${status.premium}');
    return status;
  }

  Future<SubscriptionStatus> _pollUntilPremium() async {
    final deadline = DateTime.now().add(AppConstants.subscriptionPollTimeout);
    var attempt = 0;

    while (DateTime.now().isBefore(deadline)) {
      if (_cancelPolling) {
        throw PaymentCancelledException();
      }

      await Future<void>.delayed(AppConstants.subscriptionPollInterval);

      if (_cancelPolling) {
        throw PaymentCancelledException();
      }

      attempt++;
      try {
        final status = await _repository.getSubscriptionStatus();
        debugPrint(
          '[PaymentService] poll #$attempt premium=${status.premium} '
          'planType=${status.planType}',
        );
        if (status.premium) {
          return status;
        }
      } on PaymentException catch (e) {
        debugPrint('[PaymentService] poll error (will retry): $e');
      }
    }

    throw PaymentTimeoutException();
  }

  Future<void> _activatePremium(SubscriptionStatus status) async {
    if (!status.premium) {
      throw PaymentException('Subscription is not premium yet.');
    }
    await _preferences.setBool(AppConstants.keyPremiumActive, true);
    await _preferences.setString(
      AppConstants.keyPremiumVerifiedAt,
      DateTime.now().toUtc().toIso8601String(),
    );
    await _refreshSessionUser();
  }

  Future<SubscriptionStatus> fetchSubscriptionStatus() =>
      _repository.getSubscriptionStatus();

  /// Clears global premium prefs on logout (prefs are not per-user).
  Future<void> clearPremiumCache() async {
    await _preferences.setBool(AppConstants.keyPremiumActive, false);
    await _preferences.remove(AppConstants.keyPremiumVerifiedAt);
    debugPrint('[PaymentService] clearPremiumCache');
  }

  Future<void> syncPremiumFromServer() async {
    try {
      final status = await _repository.getSubscriptionStatus();
      await _preferences.setBool(
        AppConstants.keyPremiumActive,
        status.premium,
      );
    } catch (e) {
      debugPrint('[PaymentService] syncPremiumFromServer failed: $e');
    }
  }

  Future<void> _refreshSessionUser() async {
    final session = await _sessionManager.currentSession();
    if (session == null) {
      return;
    }
    try {
      final user = await _authRemote.fetchCurrentUser(session.accessToken);
      await _sessionManager.persistSession(session.copyWith(user: user));
    } catch (e) {
      debugPrint('[PaymentService] profile refresh after payment failed: $e');
    }
  }
}
