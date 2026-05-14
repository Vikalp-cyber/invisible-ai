import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../auth/data/models/desktop_oauth_config.dart';
import '../domain/models/client_config_exception.dart';
import '../domain/models/client_runtime_config.dart';
import '../domain/models/groq_runtime_config.dart';

/// When `true` (compile-time `--dart-define=CLIENT_CONFIG_LOG_RAW=true`), logs the
/// full client-config JSON **without** masking. Use only for local debugging.
const bool _kClientConfigLogRaw = bool.fromEnvironment(
  'CLIENT_CONFIG_LOG_RAW',
  defaultValue: false,
);

/// Sort score for Groq / Deepgram key rows: default+active → active → inactive.
int _providerKeySortScore(Map<String, dynamic> row) {
  final active = row['isActive'] is bool ? row['isActive'] as bool : true;
  final isDefault = row['isDefault'] == true;
  if (isDefault && active) {
    return 0;
  }
  if (active) {
    return 1;
  }
  return 2;
}

/// Fetches unified client secrets for the **signed-in user**.
///
/// Primary: `GET /api/client-config` — nested `{ groq: {...}, deepgram: {...}, user?: ... }`.
///
/// Legacy: `GET /api/groq/client-config` — same Groq fields at the **top level**
/// (no `groq` wrapper; Deepgram omitted).
///
/// Use `Authorization: Bearer <user access token>` via [dioProvider].
class ClientConfigRepository {
  ClientConfigRepository(this._dio, this._config);

  final Dio _dio;
  final DesktopOAuthConfig _config;

  Future<ClientRuntimeConfig> fetchClientRuntimeConfig() async {
    final path = _config.clientConfigPath;
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
      final mapped = clientConfigExceptionFromDio(e);
      if (mapped != null) {
        throw mapped;
      }
      rethrow;
    }

    _log('response', {
      'path': path,
      'statusCode': response.statusCode,
      'body': _sanitizeForLog(response.data),
    });
    _logClientConfigPayload(response.data);

    final data = response.data;
    if (data == null) {
      throw StateError('Empty client config response');
    }

    // Unified: { "groq": { ... }, "deepgram": { ... }, "user": ... }
    final groqMap = data['groq'] is Map
        ? Map<String, dynamic>.from(data['groq']! as Map)
        : Map<String, dynamic>.from(data);

    final groq = _parseGroqRuntimeConfig(groqMap);

    DeepgramRuntimeConfig? deepgram;
    if (data['deepgram'] is Map) {
      deepgram = _parseDeepgramRuntimeConfig(
        Map<String, dynamic>.from(data['deepgram']! as Map),
      );
    }

    ClientUserRuntime? user;
    if (data['user'] is Map) {
      user = _parseClientUser(Map<String, dynamic>.from(data['user']! as Map));
    }

    return ClientRuntimeConfig(groq: groq, deepgram: deepgram, user: user);
  }

  GroqRuntimeConfig _parseGroqRuntimeConfig(Map<String, dynamic> data) {
    final apiKeys = _orderedGroqApiKeys(data);
    if (apiKeys.isEmpty) {
      throw ClientConfigMissingGroqKeysException();
    }

    final modelsRaw = data['models'];
    var models = <GroqModelOption>[];
    if (modelsRaw is List) {
      for (final item in modelsRaw) {
        if (item is String && item.isNotEmpty) {
          final id = GroqModelIds.canonicalize(item);
          if (id != null) {
            models.add(GroqModelOption(id: id));
          }
        } else if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          final rawId = m['id'] as String? ?? m['model'] as String?;
          final id = GroqModelIds.canonicalize(rawId);
          if (id != null) {
            models.add(
              GroqModelOption(
                id: id,
                label: m['label'] as String? ?? m['name'] as String?,
              ),
            );
          }
        }
      }
    }

    final chatModelCanon = GroqModelIds.canonicalize(
      (data['model'] as String?)?.trim(),
    );
    if (models.isEmpty && chatModelCanon != null) {
      models = [GroqModelOption(id: chatModelCanon)];
    }

    final defaultModel = GroqModelIds.canonicalize(
      (data['defaultModel'] as String?)?.trim(),
    );
    final chatBaseUrl = (data['baseUrl'] as String?)?.trim();

    return GroqRuntimeConfig(
      apiKeys: apiKeys,
      models: models,
      defaultModel: defaultModel,
      chatBaseUrl: chatBaseUrl?.isEmpty ?? true ? null : chatBaseUrl,
      chatModel: chatModelCanon,
    );
  }

  /// Prefers `keys[]` row objects; else legacy `apiKeys` strings / single `apiKey`.
  List<String> _orderedGroqApiKeys(Map<String, dynamic> data) {
    final keysRaw = data['keys'];
    if (keysRaw is List && keysRaw.isNotEmpty) {
      final rows = <Map<String, dynamic>>[];
      for (final item in keysRaw) {
        if (item is Map) {
          rows.add(Map<String, dynamic>.from(item));
        }
      }
      if (rows.isNotEmpty) {
        rows.sort(
          (a, b) => _providerKeySortScore(a).compareTo(_providerKeySortScore(b)),
        );
        return rows
            .map((r) => (r['apiKey'] as String?)?.trim() ?? '')
            .where((k) => k.isNotEmpty)
            .toList();
      }
    }

    final flat = <String>[];
    final legacyKeys = data['apiKeys'];
    if (legacyKeys is List) {
      for (final k in legacyKeys) {
        final key = k?.toString().trim() ?? '';
        if (key.isNotEmpty) {
          flat.add(key);
        }
      }
    }
    if (flat.isEmpty) {
      final singleKey = (data['apiKey'] as String?)?.trim() ?? '';
      if (singleKey.isNotEmpty) {
        flat.add(singleKey);
      }
    }
    return flat;
  }

  /// Returns [DeepgramRuntimeConfig] even when [apiKeys] is empty (caller shows
  /// "speech unavailable" and skips Deepgram).
  DeepgramRuntimeConfig _parseDeepgramRuntimeConfig(Map<String, dynamic> data) {
    final baseUrl = (data['baseUrl'] as String?)?.trim();
    final normalizedBase =
        baseUrl == null || baseUrl.isEmpty ? null : baseUrl;

    final keysRaw = data['keys'] ?? data['apiKeys'];
    if (keysRaw is List && keysRaw.isNotEmpty) {
      final rows = <Map<String, dynamic>>[];
      var hadMapRow = false;
      for (final item in keysRaw) {
        if (item is Map) {
          rows.add(Map<String, dynamic>.from(item));
          hadMapRow = true;
        }
      }
      if (hadMapRow) {
        rows.sort(
          (a, b) => _providerKeySortScore(a).compareTo(_providerKeySortScore(b)),
        );
        final ordered = rows
            .map((r) => (r['apiKey'] as String?)?.trim() ?? '')
            .where((k) => k.isNotEmpty)
            .toList();
        return DeepgramRuntimeConfig(
          apiKeys: ordered,
          baseUrl: normalizedBase,
        );
      }
      final flat = <String>[];
      for (final k in keysRaw) {
        final key = k?.toString().trim() ?? '';
        if (key.isNotEmpty) {
          flat.add(key);
        }
      }
      return DeepgramRuntimeConfig(apiKeys: flat, baseUrl: normalizedBase);
    }

    final singleKey = (data['apiKey'] as String?)?.trim() ?? '';
    final apiKeys =
        singleKey.isNotEmpty ? <String>[singleKey] : const <String>[];
    return DeepgramRuntimeConfig(apiKeys: apiKeys, baseUrl: normalizedBase);
  }

  ClientUserRuntime? _parseClientUser(Map<String, dynamic> j) {
    final id = j['id']?.toString();
    if (id == null || id.isEmpty) {
      return null;
    }
    int? readInt(String k) {
      final v = j[k];
      if (v is int) {
        return v;
      }
      if (v is num) {
        return v.toInt();
      }
      return null;
    }

    return ClientUserRuntime(
      id: id,
      email: j['email'] as String?,
      tokensUsed: readInt('tokensUsed'),
      tokenLimit: readInt('tokenLimit'),
      tokensRemaining: readInt('tokensRemaining'),
      isActive: j['isActive'] is bool ? j['isActive'] as bool : null,
    );
  }

  void _log(String phase, Map<String, dynamic> fields) {
    debugPrint('[ClientConfigRepository][$phase] ${_sanitizeForLog(fields)}');
  }

  void _logClientConfigPayload(Map<String, dynamic>? data) {
    if (data == null) {
      debugPrint('[ClientConfigRepository][response_body_json] <null body>');
      return;
    }
    debugPrint(
      '[ClientConfigRepository][response_top_level_keys] ${data.keys.toList()}',
    );
    try {
      const encoder = JsonEncoder.withIndent('  ');
      if (_kClientConfigLogRaw) {
        debugPrint(
          '[ClientConfigRepository][response_body_json_raw]\n${encoder.convert(data)}',
        );
      } else {
        final sanitized = _sanitizeForLog(data);
        debugPrint(
          '[ClientConfigRepository][response_body_json]\n${encoder.convert(sanitized)}',
        );
      }
    } catch (e) {
      debugPrint(
        '[ClientConfigRepository][response_body_json] encode failed: $e',
      );
    }
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
            lower == 'token' ||
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
    if (input is String && input.length > 12) {
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
