import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../auth/data/models/desktop_oauth_config.dart';
import '../domain/models/groq_runtime_config.dart';

/// Fetches Groq key + models for the **signed-in user**.
///
/// Expects a backend route (same [DesktopOAuthConfig.baseUrl], no host changes)
/// that returns JSON such as:
/// `{ "apiKey": "gsk_...", "models": ["id1", {"id":"id2","label":"..."}], "defaultModel": "id1" }`
///
/// Implement this on the server using the same resolution rules as
/// `GroqKeysService.resolveActiveKey()` — do **not** expose admin JWT routes
/// (`/api/admin/groq-keys`) to the desktop app.
class GroqConfigRepository {
  GroqConfigRepository(this._dio, this._config);

  final Dio _dio;
  final DesktopOAuthConfig _config;

  Future<GroqRuntimeConfig> fetchClientConfig() async {
    final path = _config.groqClientConfigPath;
    _log('request', {
      'method': 'GET',
      'path': path,
      'baseUrl': _dio.options.baseUrl,
      'query': const <String, dynamic>{},
      'payload': null,
    });

    late final Response<Map<String, dynamic>> response;
    try {
      response = await _dio.get<Map<String, dynamic>>(path);
    } on DioException catch (e) {
      _log('error', {
        'path': path,
        'statusCode': e.response?.statusCode,
        'response': _sanitizeForLog(e.response?.data),
        'message': e.message,
      });
      rethrow;
    }

    _log('response', {
      'path': path,
      'statusCode': response.statusCode,
      'body': _sanitizeForLog(response.data),
    });

    final data = response.data;
    if (data == null) {
      throw StateError('Empty Groq config response');
    }

    // ── Parse API keys ────────────────────────────────────────────────────
    // Support both `apiKeys` (list — preferred) and legacy `apiKey` (string).
    final apiKeys = <String>[];

    final keysRaw = data['apiKeys'];
    if (keysRaw is List) {
      for (final k in keysRaw) {
        final key = k?.toString().trim() ?? '';
        if (key.isNotEmpty) apiKeys.add(key);
      }
    }

    // Fallback: legacy single-key field.
    if (apiKeys.isEmpty) {
      final singleKey = (data['apiKey'] as String?)?.trim() ?? '';
      if (singleKey.isNotEmpty) apiKeys.add(singleKey);
    }

    if (apiKeys.isEmpty) {
      throw StateError('Groq config missing apiKey / apiKeys');
    }

    final modelsRaw = data['models'];
    final models = <GroqModelOption>[];
    if (modelsRaw is List) {
      for (final item in modelsRaw) {
        if (item is String && item.isNotEmpty) {
          models.add(GroqModelOption(id: item));
        } else if (item is Map) {
          final id = item['id'] as String? ?? item['model'] as String?;
          if (id != null && id.isNotEmpty) {
            models.add(
              GroqModelOption(
                id: id,
                label: item['label'] as String? ?? item['name'] as String?,
              ),
            );
          }
        }
      }
    }

    final defaultModel = data['defaultModel'] as String?;

    return GroqRuntimeConfig(
      apiKeys: apiKeys,
      models: models,
      defaultModel: defaultModel,
    );
  }

  void _log(String phase, Map<String, dynamic> fields) {
    debugPrint('[GroqConfigRepository][$phase] ${_sanitizeForLog(fields)}');
  }

  dynamic _sanitizeForLog(dynamic input) {
    if (input is Map) {
      final out = <String, dynamic>{};
      for (final entry in input.entries) {
        final key = entry.key.toString();
        final lower = key.toLowerCase();
        final value = entry.value;

        if (lower.contains('apikey') ||
            lower.contains('api_key') ||
            lower.contains('authorization') ||
            lower.contains('token') ||
            lower.contains('secret')) {
          out[key] = _maskSecret(value?.toString());
        } else {
          out[key] = _sanitizeForLog(value);
        }
      }
      return out;
    }
    if (input is List) {
      return input.map(_sanitizeForLog).toList();
    }
    if (input is String && input.startsWith('gsk_')) {
      return _maskSecret(input);
    }
    return input;
  }

  String _maskSecret(String? value) {
    if (value == null || value.isEmpty) {
      return '<empty>';
    }
    if (value.length <= 8) {
      return '***';
    }
    return '${value.substring(0, 4)}***${value.substring(value.length - 4)}';
  }
}
