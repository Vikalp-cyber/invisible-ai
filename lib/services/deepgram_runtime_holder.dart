import 'package:invisible_ai_assistant/features/assistant/domain/models/client_runtime_config.dart';

/// Holds resolved Deepgram key(s) from [ClientRuntimeConfig] for STT features.
/// Not persisted; cleared on logout when client config is invalidated.
///
/// When the backend returns multiple keys, [rotateToNextKeyAfterFailure] cycles
/// the active key after a failed connect (rate limit / auth / etc.).
class DeepgramRuntimeHolder {
  List<String> _apiKeys = const [];
  int _keyIndex = 0;
  String? _listenBaseUrl;

  void apply(DeepgramRuntimeConfig? config) {
    if (config == null) {
      _apiKeys = const [];
      _keyIndex = 0;
      _listenBaseUrl = null;
      return;
    }
    _apiKeys = List<String>.from(config.apiKeys);
    _keyIndex = 0;
    final b = config.baseUrl?.trim();
    _listenBaseUrl = b == null || b.isEmpty ? null : b;
  }

  void clear() {
    _apiKeys = const [];
    _keyIndex = 0;
    _listenBaseUrl = null;
  }

  int get keyCount => _apiKeys.length;

  /// Index of the key used for the current [currentApiKey].
  int get currentKeyIndex =>
      _apiKeys.isEmpty ? 0 : _keyIndex % _apiKeys.length;

  /// Key to pass to [DeepgramStreamingSttService.connect], if configured.
  String? get currentApiKey =>
      _apiKeys.isEmpty ? null : _apiKeys[currentKeyIndex];

  bool get hasKey => _apiKeys.isNotEmpty;

  /// REST base for building the listen WebSocket (e.g. `https://api.deepgram.com/v1`).
  String? get listenBaseUrl => _listenBaseUrl;

  /// Advance to the next key after a failed attempt. [sessionStartIndex] is
  /// [currentKeyIndex] captured before the first connect try. Returns `true` if
  /// another key is now active and the caller should retry; `false` if every
  /// key in the pool has been tried.
  bool rotateToNextKeyAfterFailure(int sessionStartIndex) {
    if (_apiKeys.length <= 1) {
      return false;
    }
    _keyIndex = (_keyIndex + 1) % _apiKeys.length;
    return _keyIndex != sessionStartIndex;
  }
}
