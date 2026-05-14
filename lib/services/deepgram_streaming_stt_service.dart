import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../features/assistant/domain/models/transcription_event.dart';

class DeepgramStreamingSttService {
  WebSocket? _socket;
  final _controller = StreamController<TranscriptionEvent>.broadcast();
  StreamSubscription<dynamic>? _socketSub;
  Timer? _keepAliveTimer;

  Stream<TranscriptionEvent> get events => _controller.stream;

  /// Builds the live listen WebSocket URI from optional REST base
  /// (e.g. `https://api.deepgram.com/v1`). When [restBaseUrl] is null, uses
  /// Deepgram's public default.
  static Uri buildListenWebSocketUri(String? restBaseUrl) {
    const qs =
        'encoding=linear16&sample_rate=16000&channels=1&interim_results=true'
        '&punctuate=true&endpointing=250&smart_format=true&model=nova-2';
    final t = restBaseUrl?.trim();
    if (t == null || t.isEmpty) {
      return Uri.parse('wss://api.deepgram.com/v1/listen?$qs');
    }
    var u = Uri.parse(t);
    var scheme = u.scheme;
    if (scheme == 'https') {
      scheme = 'wss';
    } else if (scheme == 'http') {
      scheme = 'ws';
    } else if (scheme != 'wss' && scheme != 'ws') {
      scheme = 'wss';
    }
    var path = u.path;
    if (path.isEmpty || path == '/') {
      path = '/v1/listen';
    } else if (!path.endsWith('/listen')) {
      path = path.endsWith('/') ? '${path}listen' : '$path/listen';
    }
    return u.replace(scheme: scheme, path: path, query: qs);
  }

  Future<void> connect({
    required String apiKey,
    String? listenBaseUrl,
  }) async {
    final uri = buildListenWebSocketUri(listenBaseUrl);

    _socket = await WebSocket.connect(
      uri.toString(),
      headers: <String, dynamic>{
        'Authorization': 'Token $apiKey',
      },
    );

    _socketSub = _socket!.listen(
      _handleMessage,
      onDone: _handleDone,
      onError: (Object e) => debugPrint('Deepgram socket error: $e'),
      cancelOnError: false,
    );

    _keepAliveTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_socket?.readyState == WebSocket.open) {
        _socket!.add(jsonEncode(<String, String>{'type': 'KeepAlive'}));
      }
    });
  }

  void sendAudio(Uint8List bytes) {
    if (_socket?.readyState == WebSocket.open) {
      _socket!.add(bytes);
    }
  }

  void _handleMessage(dynamic message) {
    if (message is! String) {
      return;
    }
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final channel = data['channel'] as Map<String, dynamic>?;
      if (channel == null) {
        return;
      }
      final alternatives = channel['alternatives'] as List<dynamic>?;
      if (alternatives == null || alternatives.isEmpty) {
        return;
      }
      final primary = alternatives.first as Map<String, dynamic>;
      final transcript = (primary['transcript'] as String?)?.trim() ?? '';
      if (transcript.isEmpty) {
        return;
      }
      final confidence = (primary['confidence'] as num?)?.toDouble() ?? 0.0;
      final isFinal = data['is_final'] == true;
      _controller.add(
        TranscriptionEvent(
          type: isFinal ? TranscriptionEventType.finalText : TranscriptionEventType.partial,
          text: transcript,
          confidence: confidence,
        ),
      );
    } catch (e) {
      debugPrint('Deepgram parse error: $e');
    }
  }

  void _handleDone() {
    debugPrint('Deepgram websocket closed.');
  }

  Future<void> disconnect() async {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    await _socketSub?.cancel();
    _socketSub = null;
    await _socket?.close();
    _socket = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _controller.close();
  }
}
