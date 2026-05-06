import 'dart:async';

import 'package:flutter/services.dart';

import '../features/assistant/domain/models/audio_input_device.dart';
import '../features/assistant/domain/models/transcription_event.dart';

class WindowsSpeechService {
  WindowsSpeechService()
      : _methodChannel = const MethodChannel(_methodChannelName),
        _eventChannel = const EventChannel(_eventChannelName);

  static const String _methodChannelName = 'invisible_ai_assistant/windows_speech_method';
  static const String _eventChannelName = 'invisible_ai_assistant/windows_speech_events';

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  StreamSubscription<dynamic>? _subscription;

  Future<List<AudioInputDevice>> listInputDevices() async {
    final raw = await _methodChannel.invokeMethod<List<dynamic>>('listAudioDevices');
    final devices = raw ?? const <dynamic>[];
    return devices.map((entry) {
      final map = Map<dynamic, dynamic>.from(entry as Map);
      final label = (map['label'] as String?) ?? 'Unknown device';
      return AudioInputDevice(
        id: (map['id'] as String?) ?? '',
        label: label,
        isVirtualCable: _isVirtualCable(label),
      );
    }).toList();
  }

  Future<void> startListening({
    required String? deviceId,
    required void Function(TranscriptionEvent event) onEvent,
    required void Function(Object error) onError,
  }) async {
    await _attachEventStream(onEvent: onEvent, onError: onError);
    await _methodChannel.invokeMethod<void>(
      'startListening',
      <String, dynamic>{'deviceId': deviceId},
    );
  }

  Future<void> startSystemAudioListening({
    required void Function(TranscriptionEvent event) onEvent,
    required void Function(Object error) onError,
  }) async {
    await _attachEventStream(onEvent: onEvent, onError: onError);
    await _methodChannel.invokeMethod<void>('startSystemAudioListening');
  }

  Future<void> stopListening() async {
    await _methodChannel.invokeMethod<void>('stopListening');
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _attachEventStream({
    required void Function(TranscriptionEvent event) onEvent,
    required void Function(Object error) onError,
  }) async {
    await _subscription?.cancel();
    _subscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic data) {
        if (data is! Map) {
          return;
        }
        final map = Map<dynamic, dynamic>.from(data);
        final type = (map['type'] as String?) ?? '';
        final text = (map['text'] as String?)?.trim() ?? '';
        final confidence = (map['confidence'] as num?)?.toDouble() ?? 0.0;
        if (text.isEmpty) {
          return;
        }
        if (type == 'error') {
          onError(text);
          return;
        }
        onEvent(
          TranscriptionEvent(
            type: type == 'final'
                ? TranscriptionEventType.finalText
                : TranscriptionEventType.partial,
            text: text,
            confidence: confidence,
          ),
        );
      },
      onError: onError,
      cancelOnError: false,
    );
  }

  bool _isVirtualCable(String label) {
    final lower = label.toLowerCase();
    return lower.contains('cable output') ||
        lower.contains('vb-audio') ||
        lower.contains('virtual cable');
  }

  Future<void> dispose() async {
    await stopListening();
  }
}
