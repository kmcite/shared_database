/// Failed to talk to the shared DB host (missing app, permission, or provider).
class SharedDatabaseException implements Exception {
  SharedDatabaseException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() {
    final extra = cause != null ? ' ($cause)' : '';
    return 'SharedDatabaseException: $message$extra';
  }
}
