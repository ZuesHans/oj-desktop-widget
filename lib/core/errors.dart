class FetchException implements Exception {
  FetchException(this.message);

  final String message;

  @override
  String toString() => message;
}
