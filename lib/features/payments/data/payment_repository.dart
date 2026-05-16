import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../domain/models/payment_exception.dart';
import '../domain/models/payment_link.dart';
import '../domain/models/subscription_status.dart';

class PaymentRepository {
  PaymentRepository(this._dio);

  final Dio _dio;

  static const String createLinkPath = '/api/payments/create-link';
  static const String subscriptionStatusPath = '/api/subscription/status';

  /// `POST /api/payments/create-link` — server uses `LIFETIME_PRICE_PAISE` for amount.
  Future<PaymentLink> createPaymentLink({
    String planType = AppConstants.premiumPlanType,
  }) async {
    try {
      debugPrint('[PaymentRepository] POST $createLinkPath planType=$planType');
      final response = await _dio.post<Map<String, dynamic>>(
        createLinkPath,
        data: <String, dynamic>{'planType': planType},
      );
      final data = response.data;
      if (data == null) {
        throw PaymentException('Empty response from create-link.');
      }
      final link = PaymentLink.fromJson(data);
      if (link.paymentLink.isEmpty) {
        throw PaymentException(
          'Server did not return a paymentLink URL for Razorpay checkout.',
        );
      }
      return link;
    } on DioException catch (e) {
      throw _mapDio(e, 'Could not start payment.');
    }
  }

  /// `GET /api/subscription/status` — poll until `premium: true` after webhook.
  Future<SubscriptionStatus> getSubscriptionStatus() async {
    try {
      debugPrint('[PaymentRepository] GET $subscriptionStatusPath');
      final response = await _dio.get<Map<String, dynamic>>(
        subscriptionStatusPath,
      );
      final data = response.data;
      if (data == null) {
        throw PaymentException('Empty response from subscription status.');
      }
      return SubscriptionStatus.fromJson(data);
    } on DioException catch (e) {
      throw _mapDio(e, 'Could not load subscription status.');
    }
  }

  PaymentException _mapDio(DioException e, String prefix) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    String? message;
    String? code;

    if (data is Map) {
      message = data['message']?.toString() ?? data['error']?.toString();
      code = data['code']?.toString();
    } else if (data is String && data.trim().isNotEmpty) {
      message = data.trim();
    }

    if (status == 409 && code == 'PREMIUM_ALREADY_ACTIVE') {
      return PremiumAlreadyActiveException(
        message ?? 'You already have Flowdesk Premium.',
      );
    }
    if (status == 400 && code == 'INVALID_PLAN_TYPE') {
      return PaymentException(
        message ?? 'Unsupported plan type.',
        code: code,
        httpStatus: status,
      );
    }
    if (status == 400 && code == 'MISSING_PLAN_PRICING') {
      return PaymentException(
        message ??
            'Premium pricing is not configured on the server (LIFETIME_PRICE_PAISE).',
        code: code,
        httpStatus: status,
      );
    }
    if (status == 503) {
      return PaymentException(
        message ?? 'Razorpay is not configured on the server.',
        code: code ?? 'RAZORPAY_UNAVAILABLE',
        httpStatus: status,
      );
    }

    return PaymentException(
      message != null
          ? '$prefix $message'
          : '$prefix ${e.message ?? 'Network error.'}',
      code: code,
      httpStatus: status,
    );
  }
}
