enum TranscriptionEventType {
  partial,
  finalText,
}

class TranscriptionEvent {
  const TranscriptionEvent({
    required this.type,
    required this.text,
    this.confidence = 0.0,
  });

  final TranscriptionEventType type;
  final String text;
  final double confidence;
}
