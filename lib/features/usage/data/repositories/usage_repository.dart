import 'package:dio/dio.dart';
import '../../../../core/network/network_request_flags.dart';
import '../../domain/models/token_usage.dart';
import '../../domain/models/usage_exception.dart';

class UsageRepository {
  final Dio _dio;

  const UsageRepository(this._dio);

  Future<TokenUsage> fetchUsage() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/api/usage');
      return TokenUsage.fromJson(response.data!);
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  Future<TokenUsage> consumeTokens({
    required int tokens,
    String? reason,
  }) async {
    try {
      final data = <String, dynamic>{'tokens': tokens};
      if (reason != null && reason.isNotEmpty) {
        data['reason'] = reason;
      }

      final response = await _dio.post<Map<String, dynamic>>(
        '/api/usage/consume',
        data: data,
      );
      
      return TokenUsage.fromJson(response.data!);
    } on DioException catch (e) {
      _handleDioException(e);
      rethrow;
    }
  }

  void _handleDioException(DioException error) {
    if (error.response?.statusCode == 403) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final code = data['code'] as String?;
        final message = data['message'] as String? ?? 'Token limit exceeded.';
        throw UsageException(message, code: code);
      }
      throw const UsageException('Token limit exceeded.', code: 'TOKEN_LIMIT_EXCEEDED');
    }
    
    if (error.response?.statusCode == 401) {
      throw const UsageException('Session expired. Please sign in again.', code: 'UNAUTHORIZED');
    }
    
    throw UsageException('Network error: ${error.message}', code: 'NETWORK_ERROR');
  }
}
