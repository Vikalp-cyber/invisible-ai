import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import '../features/assistant/domain/models/audio_input_device.dart';

class AudioCaptureService {
  AudioCaptureService({AudioRecorder? recorder}) : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  final Map<String, InputDevice> _deviceById = <String, InputDevice>{};
  StreamSubscription<Uint8List>? _streamSub;
  Timer? _reconnectTimer;
  String? _activeDeviceId;
  bool _disposed = false;

  Future<List<AudioInputDevice>> listInputDevices() async {
    final devices = await _recorder.listInputDevices();
    _deviceById
      ..clear()
      ..addEntries(devices.map((d) => MapEntry(d.id, d)));
    return devices
        .map(
          (d) => AudioInputDevice(
            id: d.id,
            label: d.label,
            isVirtualCable: _isVirtualCable(d.label),
          ),
        )
        .toList();
  }

  Future<void> startStreaming({
    required String? deviceId,
    required void Function(Uint8List pcmChunk) onPcmChunk,
    required void Function(Object error) onError,
  }) async {
    _activeDeviceId = deviceId;
    _reconnectTimer?.cancel();
    await _streamSub?.cancel();

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw StateError('Microphone permission denied.');
    }

    final stream = await _recorder.startStream(
      RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        autoGain: true,
        noiseSuppress: true,
        echoCancel: false,
        device: deviceId == null ? null : _deviceById[deviceId],
      ),
    );

    _streamSub = stream.listen(
      onPcmChunk,
      onError: (Object e) {
        onError(e);
        _scheduleReconnect(onPcmChunk: onPcmChunk, onError: onError);
      },
      cancelOnError: false,
    );
  }

  Future<void> stopStreaming() async {
    _reconnectTimer?.cancel();
    await _streamSub?.cancel();
    _streamSub = null;
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
  }

  void _scheduleReconnect({
    required void Function(Uint8List pcmChunk) onPcmChunk,
    required void Function(Object error) onError,
  }) {
    _reconnectTimer?.cancel();
    if (_disposed) {
      return;
    }
    _reconnectTimer = Timer(const Duration(seconds: 2), () async {
      try {
        await startStreaming(
          deviceId: _activeDeviceId,
          onPcmChunk: onPcmChunk,
          onError: onError,
        );
      } catch (e) {
        debugPrint('AudioCaptureService reconnect failed: $e');
        _scheduleReconnect(onPcmChunk: onPcmChunk, onError: onError);
      }
    });
  }

  bool _isVirtualCable(String label) {
    final lower = label.toLowerCase();
    return lower.contains('cable output') ||
        lower.contains('vb-audio') ||
        lower.contains('virtual cable');
  }

  Future<void> dispose() async {
    _disposed = true;
    await stopStreaming();
    await _recorder.dispose();
  }
}
