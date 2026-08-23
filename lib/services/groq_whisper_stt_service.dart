import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../features/assistant/domain/models/transcription_event.dart';

/// Batches PCM audio and transcribes via Groq Whisper (OpenAI-compatible API).
///
/// Tuned for Groq free tier (20 RPM on all Whisper models): ~6s chunks, silence
/// skipping, and automatic backoff on 429 instead of surfacing errors.
class GroqWhisperSttService {
  GroqWhisperSttService({
    this.sampleRate = 16000,
    this.chunkInterval = const Duration(seconds: 6),
    this.minChunkBytes = 64000,
    this.overlapBytes = 0,
    this.minSpeechRms = 350,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  static const String _transcribeUrl =
      'https://api.groq.com/openai/v1/audio/transcriptions';

  /// All Groq Whisper models share the same free-tier RPM; turbo is still the
  /// best default for latency/cost.
  static const String _model = 'whisper-large-v3-turbo';

  final int sampleRate;
  final Duration chunkInterval;
  final int minChunkBytes;
  final int overlapBytes;
  final double minSpeechRms;
  final http.Client _http;

  final _buffer = BytesBuilder(copy: false);
  final _controller = StreamController<TranscriptionEvent>.broadcast();

  Timer? _chunkTimer;
  List<String> _keys = const [];
  int _keyIndex = 0;
  bool _active = false;
  bool _busy = false;
  String _lastPartial = '';
  String _lastFinal = '';
  int _backoffUntilMs = 0;

  Stream<TranscriptionEvent> get events => _controller.stream;

  void start({required List<String> apiKeys}) {
    _keys = _normalizeKeys(apiKeys);
    if (_keys.isEmpty) {
      throw StateError('No Groq API keys configured for speech recognition.');
    }
    _keyIndex = 0;
    _lastPartial = '';
    _lastFinal = '';
    _backoffUntilMs = 0;
    _buffer.clear();
    _active = true;
    _chunkTimer?.cancel();
    _chunkTimer = Timer.periodic(chunkInterval, (_) => unawaited(_flush()));
  }

  void addPcm(Uint8List chunk) {
    if (!_active || chunk.isEmpty) {
      return;
    }
    _buffer.add(chunk);
  }

  Future<void> _flush() async {
    if (!_active || _busy || _buffer.length < minChunkBytes) {
      return;
    }
    if (DateTime.now().millisecondsSinceEpoch < _backoffUntilMs) {
      return;
    }

    _busy = true;
    try {
      final pcm = _normalizePcmBytes(_buffer.toBytes());
      if (pcm.length < minChunkBytes) {
        return;
      }
      if (!_hasSpeech(pcm)) {
        _buffer.clear();
        return;
      }
      if (pcm.length > overlapBytes) {
        _buffer.clear();
        _buffer.add(pcm.sublist(pcm.length - overlapBytes));
      } else {
        _buffer.clear();
      }

      final text = await _transcribe(pcm);
      if (text.isEmpty) {
        return;
      }

      final normalized = text.trim();
      if (normalized.isEmpty) {
        return;
      }

      if (normalized != _lastPartial) {
        _controller.add(
          TranscriptionEvent(
            type: TranscriptionEventType.partial,
            text: normalized,
          ),
        );
        _lastPartial = normalized;
      }

      if (_shouldEmitFinal(normalized)) {
        _controller.add(
          TranscriptionEvent(
            type: TranscriptionEventType.finalText,
            text: normalized,
            confidence: 0.85,
          ),
        );
        _lastFinal = normalized;
        _lastPartial = '';
      }
    } catch (e, st) {
      debugPrint('GroqWhisperSttService flush failed: $e\n$st');
      if (!_isRateLimitError(e)) {
        _controller.addError(e);
      }
    } finally {
      _busy = false;
    }
  }

  Future<String> _transcribe(Uint8List pcm) async {
    if (_keys.isEmpty) {
      return '';
    }

    final wav = _pcm16ToWav(pcm, sampleRate: sampleRate);
    final startIndex = _keyIndex;

    for (var attempt = 0; attempt < _keys.length; attempt++) {
      final key = _keys[_keyIndex];
      try {
        final request = http.MultipartRequest('POST', Uri.parse(_transcribeUrl))
          ..headers['Authorization'] = 'Bearer $key'
          ..fields['model'] = _model
          ..fields['language'] = 'en'
          ..fields['response_format'] = 'json'
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              wav,
              filename: 'audio.wav',
            ),
          );

        final streamed = await _http.send(request);
        final body = await streamed.stream.bytesToString();

        if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
          final decoded = jsonDecode(body);
          if (decoded is Map) {
            return (decoded['text'] as String?)?.trim() ?? '';
          }
          return '';
        }

        if (streamed.statusCode == 429) {
          _scheduleRateLimitBackoff(body);
          return '';
        }

        if (_shouldRotateKey(streamed.statusCode) && _keys.length > 1) {
          _keyIndex = (_keyIndex + 1) % _keys.length;
          if (_keyIndex == startIndex) {
            break;
          }
          continue;
        }

        throw HttpException(
          'Groq Whisper failed (${streamed.statusCode}): $body',
          uri: Uri.parse(_transcribeUrl),
        );
      } on SocketException {
        if (_keys.length > 1) {
          _keyIndex = (_keyIndex + 1) % _keys.length;
          if (_keyIndex == startIndex) {
            rethrow;
          }
          continue;
        }
        rethrow;
      }
    }

    return '';
  }

  void _scheduleRateLimitBackoff(String body) {
    var waitSeconds = 5;
    final match = RegExp(r'try again in (\d+)s', caseSensitive: false).firstMatch(body);
    if (match != null) {
      waitSeconds = int.tryParse(match.group(1) ?? '') ?? waitSeconds;
    }
    waitSeconds = waitSeconds.clamp(3, 30);
    _backoffUntilMs = DateTime.now().millisecondsSinceEpoch + (waitSeconds * 1000);
    debugPrint(
      'GroqWhisperSttService: rate limited — backing off ${waitSeconds}s '
      '(free tier: 20 requests/min on all Whisper models)',
    );
  }

  bool _isRateLimitError(Object e) {
    final text = e.toString();
    return text.contains('429') || text.contains('rate_limit');
  }

  bool _hasSpeech(Uint8List pcm) {
    if (pcm.length < 4) {
      return false;
    }
    var sumSquares = 0.0;
    final sampleCount = pcm.length ~/ 2;
    for (var i = 0; i + 1 < pcm.length; i += 2) {
      final sample = pcm[i] | (pcm[i + 1] << 8);
      final signed = sample >= 0x8000 ? sample - 0x10000 : sample;
      sumSquares += signed * signed;
    }
    final rms = sqrt(sumSquares / sampleCount);
    return rms >= minSpeechRms;
  }

  bool _shouldRotateKey(int statusCode) {
    return statusCode == 401 ||
        statusCode == 403 ||
        statusCode >= 500;
  }

  Future<void> stop() async {
    _active = false;
    _chunkTimer?.cancel();
    _chunkTimer = null;

    if (_buffer.length >= minChunkBytes ~/ 2) {
      await _flush();
    }
    _buffer.clear();
    _lastPartial = '';
    _lastFinal = '';
    _backoffUntilMs = 0;
  }

  bool _shouldEmitFinal(String text) {
    if (_lastFinal.isEmpty) {
      return true;
    }
    if (text == _lastFinal) {
      return false;
    }
    if (text.startsWith(_lastFinal)) {
      return true;
    }
    if (_lastFinal.startsWith(text)) {
      return false;
    }
    return true;
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
    _http.close();
  }

  List<String> _normalizeKeys(List<String> keys) {
    final seen = <String>{};
    final out = <String>[];
    for (final key in keys) {
      final trimmed = key.trim();
      if (trimmed.isEmpty || seen.contains(trimmed)) {
        continue;
      }
      seen.add(trimmed);
      out.add(trimmed);
    }
    return out;
  }

  Uint8List _normalizePcmBytes(Uint8List pcm) {
    if (pcm.isEmpty) {
      return pcm;
    }
    if (pcm.length.isOdd) {
      return Uint8List.sublistView(pcm, 0, pcm.length - 1);
    }
    return pcm;
  }

  Uint8List _pcm16ToWav(Uint8List pcm, {required int sampleRate}) {
    const channels = 1;
    const bitsPerSample = 16;
    final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    const blockAlign = channels * (bitsPerSample ~/ 8);
    final dataSize = pcm.length;
    final riffChunkSize = 36 + dataSize;

    final header = ByteData(44);
    header.setUint8(0, 0x52);
    header.setUint8(1, 0x49);
    header.setUint8(2, 0x46);
    header.setUint8(3, 0x46);
    header.setUint32(4, riffChunkSize, Endian.little);
    header.setUint8(8, 0x57);
    header.setUint8(9, 0x41);
    header.setUint8(10, 0x56);
    header.setUint8(11, 0x45);
    header.setUint8(12, 0x66);
    header.setUint8(13, 0x6D);
    header.setUint8(14, 0x74);
    header.setUint8(15, 0x20);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    header.setUint8(36, 0x64);
    header.setUint8(37, 0x61);
    header.setUint8(38, 0x74);
    header.setUint8(39, 0x61);
    header.setUint32(40, dataSize, Endian.little);

    return Uint8List.fromList(<int>[
      ...header.buffer.asUint8List(0, 44),
      ...pcm,
    ]);
  }
}
