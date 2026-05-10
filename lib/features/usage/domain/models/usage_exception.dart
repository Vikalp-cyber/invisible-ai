class UsageException implements Exception {
  final String message;
  final String? code;

  const UsageException(this.message, {this.code});

  @override
  String toString() => 'UsageException: $message (code: $code)';
}
