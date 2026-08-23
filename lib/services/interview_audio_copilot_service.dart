import 'dart:async';

import 'package:flutter/foundation.dart';

import '../features/assistant/domain/models/audio_input_device.dart';
import '../features/assistant/domain/models/detected_question.dart';
import '../features/assistant/domain/models/transcription_event.dart';
import 'audio_capture_service.dart';
import 'deepgram_runtime_holder.dart';
import 'deepgram_streaming_stt_service.dart';
import 'groq_whisper_stt_service.dart';
import 'question_detection_service.dart';
import 'windows_local_stt_service.dart';
import 'windows_speech_service.dart';

/// Interview / speaker copilot: speech-to-text then question detection.
///
/// Microphone priority: **Deepgram** → **Windows local (free)** → **Groq Whisper**
/// → legacy SAPI.
///
/// Speaker/loopback: **Deepgram** → **Groq Whisper** (no free cloud-free option).
///
/// When [resolveDeepgramHolder] returns a holder with **multiple** keys, connect
/// failures rotate through keys (rate limit / auth / network) before surfacing an error.
class InterviewAudioCopilotService {
  InterviewAudioCopilotService({
    WindowsSpeechService? speechService,
    QuestionDetectionService? questionDetectionService,
    AudioCaptureService? audioCaptureService,
    DeepgramStreamingSttService? deepgramStreaming,
    GroqWhisperSttService? groqWhisperStt,
    WindowsLocalSttService? windowsLocalStt,
    DeepgramRuntimeHolder? Function()? resolveDeepgramHolder,
    String? Function()? resolveDeepgramApiKey,
    String? Function()? resolveDeepgramListenBaseUrl,
    List<String> Function()? resolveGroqApiKeys,
  })  : _speechService = speechService ?? WindowsSpeechService(),
        _questionDetectionService = questionDetectionService ?? QuestionDetectionService(),
        _audioCapture = audioCaptureService ?? AudioCaptureService(),
        _deepgram = deepgramStreaming ?? DeepgramStreamingSttService(),
        _groqWhisper = groqWhisperStt ?? GroqWhisperSttService(),
        _windowsLocalStt = windowsLocalStt ?? WindowsLocalSttService(),
        _resolveDeepgramHolder = resolveDeepgramHolder,
        _resolveDeepgramApiKey = resolveDeepgramApiKey,
        _resolveDeepgramListenBaseUrl = resolveDeepgramListenBaseUrl,
        _resolveGroqApiKeys = resolveGroqApiKeys;

  final WindowsSpeechService _speechService;
  final QuestionDetectionService _questionDetectionService;
  final AudioCaptureService _audioCapture;
  final DeepgramStreamingSttService _deepgram;
  final GroqWhisperSttService _groqWhisper;
  final WindowsLocalSttService _windowsLocalStt;
  final DeepgramRuntimeHolder? Function()? _resolveDeepgramHolder;
  final String? Function()? _resolveDeepgramApiKey;
  final String? Function()? _resolveDeepgramListenBaseUrl;
  final List<String> Function()? _resolveGroqApiKeys;

  StreamSubscription<TranscriptionEvent>? _deepgramSub;
  StreamSubscription<TranscriptionEvent>? _groqWhisperSub;
  StreamSubscription<TranscriptionEvent>? _windowsLocalSub;
  StreamSubscription<dynamic>? _pcmSub;

  bool _active = false;
  bool _usingDeepgramMic = false;
  bool _usingDeepgramSystem = false;
  bool _usingWindowsLocalMic = false;
  bool _usingGroqMic = false;
  bool _usingGroqSystem = false;

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

  List<String> get _groqKeys {
    final keys = _resolveGroqApiKeys?.call() ?? const <String>[];
    return keys.map((k) => k.trim()).where((k) => k.isNotEmpty).toList();
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
    if (_deepgramKey != null || _groqKeys.isNotEmpty) {
      return _audioCapture.listInputDevices();
    }
    if (WindowsLocalSttService.isSupported) {
      return _speechService.listInputDevices();
    }
    return _speechService.listInputDevices();
  }

  bool _isTransientSttError(Object e) {
    final text = e.toString().toLowerCase();
    return text.contains('429') ||
        text.contains('rate_limit') ||
        text.contains('rate limit');
  }

  Future<bool> _startWindowsLocalMic({
    required void Function(String partialText) onPartialTranscript,
    required void Function(String finalText) onFinalTranscript,
    required void Function(DetectedQuestion question) onQuestionDetected,
    required void Function(Object error) onError,
  }) async {
    if (!WindowsLocalSttService.isSupported) {
      return false;
    }
    try {
      await _windowsLocalStt.start();
      _windowsLocalSub?.cancel();
      _windowsLocalSub = _windowsLocalStt.events.listen(
        (event) => _dispatchEvent(
          event: event,
          onPartialTranscript: onPartialTranscript,
          onFinalTranscript: onFinalTranscript,
          onQuestionDetected: onQuestionDetected,
        ),
        onError: onError,
      );
      _usingWindowsLocalMic = true;
      _active = true;
      return true;
    } catch (e, st) {
      debugPrint('InterviewAudioCopilotService Windows local STT failed: $e\n$st');
      await _stopWindowsLocalMic();
      return false;
    }
  }

  Future<bool> _startGroqMic({
    required String? deviceId,
    required void Function(String partialText) onPartialTranscript,
    required void Function(String finalText) onFinalTranscript,
    required void Function(DetectedQuestion question) onQuestionDetected,
    required void Function(Object error) onError,
    required List<String> groqKeys,
  }) async {
    try {
      _groqWhisper.start(apiKeys: groqKeys);
      await _groqWhisperSub?.cancel();
      _groqWhisperSub = _groqWhisper.events.listen(
        (event) => _dispatchEvent(
          event: event,
          onPartialTranscript: onPartialTranscript,
          onFinalTranscript: onFinalTranscript,
          onQuestionDetected: onQuestionDetected,
        ),
        onError: (Object e) {
          if (_isTransientSttError(e)) {
            debugPrint('InterviewAudioCopilotService Groq STT transient: $e');
            return;
          }
          onError(e);
        },
      );

      await _audioCapture.listInputDevices();
      await _audioCapture.startStreaming(
        deviceId: deviceId,
        onPcmChunk: _groqWhisper.addPcm,
        onError: onError,
      );
      _usingGroqMic = true;
      _active = true;
      return true;
    } catch (e, st) {
      debugPrint('InterviewAudioCopilotService Groq Whisper start failed: $e\n$st');
      await _stopGroqMic();
      return false;
    }
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
        await _stopGroqMic();
        await _stopGroqSystem();
        await _stopWindowsLocalMic();
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
    await _stopGroqMic();
    await _stopGroqSystem();
    await _stopWindowsLocalMic();

    if (await _startWindowsLocalMic(
      onPartialTranscript: onPartialTranscript,
      onFinalTranscript: onFinalTranscript,
      onQuestionDetected: onQuestionDetected,
      onError: onError,
    )) {
      return;
    }

    final groqKeys = _groqKeys;
    if (groqKeys.isNotEmpty) {
      final started = await _startGroqMic(
        deviceId: deviceId,
        groqKeys: groqKeys,
        onPartialTranscript: onPartialTranscript,
        onFinalTranscript: onFinalTranscript,
        onQuestionDetected: onQuestionDetected,
        onError: onError,
      );
      if (started) {
        return;
      }
    }

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
        await _stopGroqMic();
        await _stopGroqSystem();
        await _stopWindowsLocalMic();
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
    await _stopGroqMic();
    await _stopGroqSystem();

    final groqKeys = _groqKeys;
    if (groqKeys.isNotEmpty) {
      try {
        _groqWhisper.start(apiKeys: groqKeys);
        _groqWhisperSub = _groqWhisper.events.listen(
          (event) => _dispatchEvent(
            event: event,
            onPartialTranscript: onPartialTranscript,
            onFinalTranscript: onFinalTranscript,
            onQuestionDetected: onQuestionDetected,
          ),
          onError: (Object e) {
            if (_isTransientSttError(e)) {
              debugPrint('InterviewAudioCopilotService Groq system STT transient: $e');
              return;
            }
            onError(e);
          },
        );

        _pcmSub = _speechService.loopbackPcmStream.listen(
          (dynamic data) {
            if (data is Uint8List && data.isNotEmpty) {
              _groqWhisper.addPcm(data);
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
        _usingGroqSystem = true;
        _active = true;
      } catch (e, st) {
        debugPrint(
          'InterviewAudioCopilotService Groq Whisper system start failed: $e\n$st',
        );
        onError(e);
        await _stopGroqSystem();
      }
      return;
    }

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

  Future<void> _stopWindowsLocalMic() async {
    await _windowsLocalSub?.cancel();
    _windowsLocalSub = null;
    await _windowsLocalStt.stop();
    _usingWindowsLocalMic = false;
  }

  Future<void> _stopGroqMic() async {
    await _groqWhisperSub?.cancel();
    _groqWhisperSub = null;
    await _audioCapture.stopStreaming();
    await _groqWhisper.stop();
    _usingGroqMic = false;
  }

  Future<void> _stopGroqSystem() async {
    await _speechService.stopLoopbackPcm();
    await _pcmSub?.cancel();
    _pcmSub = null;
    await _groqWhisperSub?.cancel();
    _groqWhisperSub = null;
    await _groqWhisper.stop();
    _usingGroqSystem = false;
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
      } else if (_usingWindowsLocalMic) {
        await _stopWindowsLocalMic();
      } else if (_usingGroqMic) {
        await _stopGroqMic();
      } else if (_usingGroqSystem) {
        await _stopGroqSystem();
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
    await _groqWhisper.dispose();
    await _windowsLocalStt.dispose();
    await _speechService.dispose();
  }
}
