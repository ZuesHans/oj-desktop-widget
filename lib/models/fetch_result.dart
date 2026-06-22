class OjProfile {
  const OjProfile({
    required this.solvedCount,
    required this.profileUrl,
    this.rating,
    this.source = 'unknown',
  });

  final int solvedCount;
  final int? rating;
  final String profileUrl;
  final String source;
}

enum FetchStatus { idle, success, failure }

class FetchResult {
  const FetchResult({
    required this.ojId,
    required this.username,
    required this.status,
    required this.fetchedAt,
    this.solvedCount,
    this.rating,
    this.profileUrl,
    this.error,
    this.source = 'unknown',
    this.previousSolvedCount,
  });

  factory FetchResult.success({
    required String ojId,
    required String username,
    required int solvedCount,
    required DateTime fetchedAt,
    int? rating,
    String? profileUrl,
    String source = 'unknown',
    int? previousSolvedCount,
  }) {
    return FetchResult(
      ojId: ojId,
      username: username,
      status: FetchStatus.success,
      solvedCount: solvedCount,
      rating: rating,
      profileUrl: profileUrl,
      fetchedAt: fetchedAt,
      source: source,
      previousSolvedCount: previousSolvedCount,
    );
  }

  factory FetchResult.failure({
    required String ojId,
    required String username,
    required String error,
    required DateTime fetchedAt,
    String source = 'unknown',
    int? solvedCount,
    int? previousSolvedCount,
  }) {
    return FetchResult(
      ojId: ojId,
      username: username,
      status: FetchStatus.failure,
      error: error,
      fetchedAt: fetchedAt,
      source: source,
      solvedCount: solvedCount,
      previousSolvedCount: previousSolvedCount,
    );
  }

  final String ojId;
  final String username;
  final FetchStatus status;
  final int? solvedCount;
  final int? rating;
  final String? profileUrl;
  final String? error;
  final String source;
  final int? previousSolvedCount;
  final DateTime? fetchedAt;

  FetchResult copyWith({
    FetchStatus? status,
    int? solvedCount,
    int? rating,
    String? profileUrl,
    String? error,
    String? source,
    int? previousSolvedCount,
  }) {
    return FetchResult(
      ojId: ojId,
      username: username,
      status: status ?? this.status,
      fetchedAt: fetchedAt,
      solvedCount: solvedCount ?? this.solvedCount,
      rating: rating ?? this.rating,
      profileUrl: profileUrl ?? this.profileUrl,
      error: error ?? this.error,
      source: source ?? this.source,
      previousSolvedCount: previousSolvedCount ?? this.previousSolvedCount,
    );
  }
}
