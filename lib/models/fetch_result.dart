class OjProfile {
  const OjProfile({
    required this.solvedCount,
    required this.profileUrl,
    this.rating,
  });

  final int solvedCount;
  final int? rating;
  final String profileUrl;
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
  });

  factory FetchResult.success({
    required String ojId,
    required String username,
    required int solvedCount,
    required DateTime fetchedAt,
    int? rating,
    String? profileUrl,
  }) {
    return FetchResult(
      ojId: ojId,
      username: username,
      status: FetchStatus.success,
      solvedCount: solvedCount,
      rating: rating,
      profileUrl: profileUrl,
      fetchedAt: fetchedAt,
    );
  }

  factory FetchResult.failure({
    required String ojId,
    required String username,
    required String error,
    required DateTime fetchedAt,
  }) {
    return FetchResult(
      ojId: ojId,
      username: username,
      status: FetchStatus.failure,
      error: error,
      fetchedAt: fetchedAt,
    );
  }

  final String ojId;
  final String username;
  final FetchStatus status;
  final int? solvedCount;
  final int? rating;
  final String? profileUrl;
  final String? error;
  final DateTime? fetchedAt;
}
