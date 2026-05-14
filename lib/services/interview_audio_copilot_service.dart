import 'dart:async';

import 'package:flutter/foundation.dart';

import '../features/assistant/domain/models/audio_input_device.dart';
import '../features/assistant/domain/models/detected_question.dart';
import '../features/assistant/domain/models/transcription_event.dart';
import 'audio_capture_service.dart';
import 'deepgram_runtime_holder.dart';
import 'deepgram_streaming_stt_service.dart';
import 'question_detection_service.dart';
import 'windows_speech_service.dart';

/// Interview / speaker copilot: speech-to-text then question detection.
///
/// With a Deepgram API key from the backend, **microphone** uses `record` + Deepgram
/// and **system speaker (loopback)** uses WASAPI loopback (native) + Deepgram per
/// [Deepgram live streaming](https://developers.deepgram.com/docs/live-streaming-audio)
/// (`linear16`, 16 kHz, mono over WebSocket).
///
/// When [resolveDeepgramHolder] returns a holder with **multiple** keys, connect
/// failures rotate through keys (rate limit / auth / network) before surfacing an error.
///
/// Without a key, Windows SAPI is used (mic and system audio).
class InterviewAudioCopilotService {
  InterviewAudioCopilotService({
    WindowsSpeechService? speechService,
    QuestionDetectionService? questionDetectionService,
    AudioCaptureService? audioCaptureService,
    DeepgramStreamingSttService? deepgramStreaming,
    DeepgramRuntimeHolder? Function()? resolveDeepgramHolder,
    String? Function()? resolveDeepgramApiKey,
    String? Function()? resolveDeepgramListenBaseUrl,
  })  : _speechService = speechService ?? WindowsSpeechService(),
        _questionDetectionService = questionDetectionService ?? QuestionDetectionService(),
        _audioCapture = audioCaptureService ?? AudioCaptureService(),
        _deepgram = deepgramStreaming ?? DeepgramStreamingSttService(),
        _resolveDeepgramHolder = resolveDeepgramHolder,
        _resolveDeepgramApiKey = resolveDeepgramApiKey,
        _resolveDeepgramListenBaseUrl = resolveDeepgramListenBaseUrl;

  final WindowsSpeechService _speechService;
  final QuestionDetectionService _questionDetectionService;
  final AudioCaptureService _audioCapture;
  final DeepgramStreamingSttService _deepgram;
  final DeepgramRuntimeHolder? Function()? _resolveDeepgramHolder;
  final String? Function()? _resolveDeepgramApiKey;
  final String? Function()? _resolveDeepgramListenBaseUrl;

  StreamSubscription<TranscriptionEvent>? _deepgramSub;
  StreamSubscription<dynamic>? _pcmSub;

  bool _active = false;
  bool _usingDeepgramMic = false;
  bool _usingDeepgramSystem = false;

  bool get isActive => _active;

  String? get _deepgramKey {
    final fromHolder = _resolveDeepgramHolder?.call()?.currentApiKey?.trim();
    if (fromHolder != null && fromHolder.isNotEmpty) {
      return fromHolder;
    }
    final raw = _resolveDeepgramApiKey?.call()?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return raw;
  }

  Future<void> _connectDeepgramWithKeyFallback(String? listenBaseUrl) async {
    final holder = _resolveDeepgramHolder?.call();
    final sessionStartIndex = holder?.currentKeyIndex ?? 0;

    for (;;) {
      final key = holder?.currentApiKey ??
          _resolveDeepgramApiKey?.call()?.trim();
      if (key == null || key.isEmpty) {
        throw StateError('No Deepgram API key');
      }
      try {
        await _deepgram.connect(
          apiKey: key,
          listenBaseUrl: listenBaseUrl,
        );
        return;
      } catch (e, st) {
        debugPrint(
          'InterviewAudioCopilotService Deepgram connect failed '
          '(keyIndex=${holder?.currentKeyIndex}): $e\n$st',
        );
        await _deepgram.disconnect();
        final canRotate = holder != null &&
            holder.keyCount > 1 &&
            holder.rotateToNextKeyAfterFailure(sessionStartIndex);
        if (!canRotate) {
          rethrow;
        }
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  Future<List<AudioInputDevice>> listDevices() async {
    if (_deepgramKey != null) {
      return _audioCapture.listInputDevices();
    }
    return _speechService.listInputDevices();
  }

  Future<void> start({
    required String? deviceId,
    required void Function(String partialText) onPartialTranscript,
    required void Function(String finalText) onFinalTranscript,
    required void Function(DetectedQuestion question) onQuestionDetected,
    required void Function(Object error) onError,
  }) async {
    if (_active) {
      await stop();
    }

    final key = _deepgramKey;
    if (key != null) {
      try {
        await _speechService.stopListening();
        await _speechService.stopLoopbackPcm();
        await _pcmSub?.cancel();
        _pcmSub = null;
        await _deepgramSub?.cancel();
        _deepgramSub = null;
        await _audioCapture.stopStreaming();
        await _deepgram.disconnect();

        await _connectDeepgramWithKeyFallback(
          _resolveDeepgramListenBaseUrl?.call(),
        );
        _deepgramSub = _deepgram.events.listen(
          (event) => _dispatchEvent(
            event: event,
            onPartialTranscript: onPartialTranscript,
            onFinalTranscript: onFinalTranscript,
            onQuestionDetected: onQuestionDetected,
          ),
          onError: onError,
        );

        await _audioCapture.listInputDevices();
        await _audioCapture.startStreaming(
          deviceId: deviceId,
          onPcmChunk: _deepgram.sendAudio,
          onError: onError,
        );
        _usingDeepgramMic = true;
        _active = true;
      } catch (e, st) {
        debugPrint('InterviewAudioCopilotService Deepgram start failed: $e\n$st');
        onError(e);
        await _stopDeepgramMic();
      }
      return;
    }

    await _stopDeepgramMic();
    await _stopDeepgramSystem();

    await _speechService.startListening(
      deviceId: deviceId,
      onEvent: (event) => _dispatchEvent(
        event: event,
        onPartialTranscript: onPartialTranscript,
        onFinalTranscript: onFinalTranscript,
        onQuestionDetected: onQuestionDetected,
      ),
      onError: onError,
    );

    _active = true;
  }

  Future<void> startSystemAudio({
    required void Function(String partialText) onPartialTranscript,
    required void Function(String finalText) onFinalTranscript,
    required void Function(DetectedQuestion question) onQuestionDetected,
    required void Function(Object error) onError,
  }) async {
    if (_active) {
      await stop();
    }

    final key = _deepgramKey;
    if (key != null) {
      try {
        await _speechService.stopListening();
        await _speechService.stopLoopbackPcm();
        await _pcmSub?.cancel();
        _pcmSub = null;
        await _deepgramSub?.cancel();
        _deepgramSub = null;
        await _audioCapture.stopStreaming();
        await _deepgram.disconnect();

        await _connectDeepgramWithKeyFallback(
          _resolveDeepgramListenBaseUrl?.call(),
        );
        _deepgramSub = _deepgram.events.listen(
          (event) => _dispatchEvent(
            event: event,
            onPartialTranscript: onPartialTranscript,
            onFinalTranscript: onFinalTranscript,
            onQuestionDetected: onQuestionDetected,
          ),
          onError: onError,
        );

        _pcmSub = _speechService.loopbackPcmStream.listen(
          (dynamic data) {
            if (data is Uint8List && data.isNotEmpty) {
              _deepgram.sendAudio(data);
              return;
            }
            if (data is Map) {
              final map = Map<Object?, Object?>.from(data);
              if (map['type'] == 'error') {
                onError(map['message']?.toString() ?? 'Loopback PCM error');
              }
            }
          },
          onError: onError,
        );

        await _speechService.startLoopbackPcm();
        _usingDeepgramSystem = true;
        _active = true;
      } catch (e, st) {
        debugPrint('InterviewAudioCopilotService Deepgram system start failed: $e\n$st');
        onError(e);
        await _stopDeepgramSystem();
      }
      return;
    }

    await _stopDeepgramSystem();

    await _speechService.startSystemAudioListening(
      onEvent: (event) => _dispatchEvent(
        event: event,
        onPartialTranscript: onPartialTranscript,
        onFinalTranscript: onFinalTranscript,
        onQuestionDetected: onQuestionDetected,
      ),
      onError: onError,
    );

    _active = true;
  }

  Future<void> _stopDeepgramMic() async {
    await _deepgramSub?.cancel();
    _deepgramSub = null;
    await _audioCapture.stopStreaming();
    await _deepgram.disconnect();
    _usingDeepgramMic = false;
  }

  Future<void> _stopDeepgramSystem() async {
    await _speechService.stopLoopbackPcm();
    await _pcmSub?.cancel();
    _pcmSub = null;
    await _deepgramSub?.cancel();
    _deepgramSub = null;
    await _deepgram.disconnect();
    _usingDeepgramSystem = false;
  }

  void _dispatchEvent({
    required TranscriptionEvent event,
    required void Function(String partialText) onPartialTranscript,
    required void Function(String finalText) onFinalTranscript,
    required void Function(DetectedQuestion question) onQuestionDetected,
  }) {
    switch (event.type) {
      case TranscriptionEventType.partial:
        onPartialTranscript(event.text);
      case TranscriptionEventType.finalText:
        onFinalTranscript(event.text);
        final detected = _questionDetectionService.detect(event.text);
        if (detected != null) {
          onQuestionDetected(detected);
        }
    }
  }

  Future<void> stop() async {
    try {
      if (_usingDeepgramMic) {
        await _stopDeepgramMic();
      } else if (_usingDeepgramSystem) {
        await _stopDeepgramSystem();
      } else {
        await _speechService.stopListening();
      }
    } catch (e) {
      debugPrint('InterviewAudioCopilotService stop error: $e');
    } finally {
      _active = false;
    }
  }

  Future<void> dispose() async {
    try {
      await stop();
    } catch (e) {
      debugPrint('InterviewAudioCopilotService dispose stop error: $e');
    }
    await _audioCapture.dispose();
    await _deepgram.dispose();
    await _speechService.dispose();
  }
}
