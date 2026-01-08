final class TakumiException implements Exception {
  final String message;
  final Object? cause;

  const TakumiException(this.message, {
    this.cause,
  });

  @override
  String toString() => 'TakumiException: $message\nCause:${Error.safeToString(cause)}';
}
