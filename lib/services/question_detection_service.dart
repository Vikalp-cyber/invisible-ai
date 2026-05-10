import '../features/assistant/domain/models/detected_question.dart';

class QuestionDetectionService {
  final Map<String, DateTime> _recent = <String, DateTime>{};

  DetectedQuestion? detect(String transcript) {
    final normalized = _normalize(transcript);
    if (normalized.length < 12) {
      return null;
    }
    if (_isFiller(normalized)) {
      return null;
    }

    final looksLikeQuestion =
        normalized.endsWith('?') ||
        _questionPatterns.any((pattern) => pattern.hasMatch(normalized));
    if (!looksLikeQuestion) {
      return null;
    }

    final score = _confidence(normalized);
    if (score < 0.5) {
      return null;
    }

    if (_isDuplicate(normalized)) {
      return null;
    }

    _recent[normalized] = DateTime.now();
    _gc();
    return DetectedQuestion(
      text: _cleanupQuestion(transcript),
      confidence: score,
    );
  }

  static final List<RegExp> _questionPatterns = <RegExp>[
    RegExp(
      r'^(explain|describe|tell me|what is|what are)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(difference between|how would you|why do we|when would you)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(implement|optimize|design|architecture|dependency injection)\b',
      caseSensitive: false,
    ),
  ];

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  bool _isFiller(String text) {
    const fillers = <String>[
      'uh',
      'umm',
      'okay',
      'right',
      'you know',
      'hmm',
      'let me think',
    ];
    return fillers.any((word) => text == word || text.startsWith('$word '));
  }

  bool _isDuplicate(String normalized) {
    final existing = _recent[normalized];
    if (existing == null) {
      return false;
    }
    return DateTime.now().difference(existing) < const Duration(seconds: 35);
  }

  void _gc() {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 3));
    _recent.removeWhere((_, ts) => ts.isBefore(cutoff));
  }

  double _confidence(String normalized) {
    var score = 0.0;
    if (normalized.endsWith('?')) {
      score += 0.4;
    }
    if (_questionPatterns.any((p) => p.hasMatch(normalized))) {
      score += 0.45;
    }
    if (normalized.length > 22) {
      score += 0.15;
    }
    return score.clamp(0.0, 1.0);
  }

  String _cleanupQuestion(String text) {
    var cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (!cleaned.endsWith('?')) {
      cleaned = '$cleaned?';
    }
    return cleaned;
  }
}
