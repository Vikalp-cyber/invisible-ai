import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/network_request_flags.dart';
import '../domain/models/payment_exception.dart';
import '../domain/models/pricing_plan.dart';

class PricingRepository {
  PricingRepository(this._dio);

  final Dio _dio;

  static const String plansPath = '/api/pricing/plans';

  /// Public — no Bearer token required.
  Future<List<PricingPlan>> fetchPlans() async {
    try {
      debugPrint('[PricingRepository] GET $plansPath (public)');
      final response = await _dio.get<Map<String, dynamic>>(
        plansPath,
        options: Options(
          extra: <String, dynamic>{skipAuthRequestFlag: true},
        ),
      );
      final data = response.data;
      if (data == null) {
        throw PaymentException('Empty response from pricing plans.');
      }
      final parsed = PricingPlansResponse.fromJson(data);
      return parsed.plans.where((p) => p.planType.isNotEmpty).toList();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      String? message;
      if (body is Map) {
        message = body['message']?.toString();
      }
      throw PaymentException(
        message != null
            ? 'Could not load pricing. $message'
            : 'Could not load pricing. ${e.message ?? 'Network error.'}',
        httpStatus: status,
      );
    }
  }
}
