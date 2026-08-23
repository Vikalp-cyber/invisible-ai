import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../features/assistant/domain/models/transcription_event.dart';

/// Free on-device speech recognition via Windows WinRT APIs (`speech_to_text`).
///
/// Works offline when the Windows language pack is installed. No API key or
/// rate limits. Uses the system default microphone.
class WindowsLocalSttService {
  WindowsLocalSttService({SpeechToText? speech})
      : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  final _controller = StreamController<TranscriptionEvent>.broadcast();

  bool _initialized = false;
  bool _listening = false;

  Stream<TranscriptionEvent> get events => _controller.stream;

  static bool get isSupported => Platform.isWindows;

  Future<void> start() async {
    if (!isSupported) {
      throw StateError('Windows local speech recognition is only available on Windows.');
    }

    if (!_initialized) {
      final ok = await _speech.initialize(
        onError: (error) {
          debugPrint('WindowsLocalSttService error: ${error.errorMsg}');
          _controller.addError(error.errorMsg);
        },
        onStatus: (status) {
          debugPrint('WindowsLocalSttService status: $status');
        },
      );
      if (!ok) {
        throw StateError(
          'Windows speech recognition unavailable. Enable microphone access '
          'and install an English speech language pack in Windows Settings.',
        );
      }
      _initialized = true;
    }

    if (_listening) {
      await stop();
    }

    final started = await _speech.listen(
      onResult: (result) {
        final text = result.recognizedWords.trim();
        if (text.isEmpty) {
          return;
        }
        _controller.add(
          TranscriptionEvent(
            type: result.finalResult
                ? TranscriptionEventType.finalText
                : TranscriptionEventType.partial,
            text: text,
            confidence: result.confidence,
          ),
        );
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
    );

    if (!started) {
      throw StateError('Failed to start Windows speech recognition.');
    }
    _listening = true;
  }

  Future<void> stop() async {
    if (_listening) {
      await _speech.stop();
      _listening = false;
    }
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}
