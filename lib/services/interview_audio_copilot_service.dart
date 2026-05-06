import 'dart:async';

import 'package:flutter/foundation.dart';

import '../features/assistant/domain/models/audio_input_device.dart';
import '../features/assistant/domain/models/detected_question.dart';
import '../features/assistant/domain/models/transcription_event.dart';
import 'question_detection_service.dart';
import 'windows_speech_service.dart';

class InterviewAudioCopilotService {
  InterviewAudioCopilotService({
    WindowsSpeechService? speechService,
    QuestionDetectionService? questionDetectionService,
  })  : _speechService = speechService ?? WindowsSpeechService(),
        _questionDetectionService = questionDetectionService ?? QuestionDetectionService();

  final WindowsSpeechService _speechService;
  final QuestionDetectionService _questionDetectionService;

  bool _active = false;

  bool get isActive => _active;

  Future<List<AudioInputDevice>> listDevices() => _speechService.listInputDevices();

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
      await _speechService.stopListening();
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
    await _speechService.dispose();
  }
}
