part of '../main.dart';

class SolvedSnapshot {
  const SolvedSnapshot({
    required this.date,
    required this.fetchedAt,
    required this.ojId,
    required this.username,
    required this.status,
    this.solvedCount,
    this.error,
  });

  factory SolvedSnapshot.fromResult(FetchResult result) {
    final fetchedAt = result.fetchedAt ?? DateTime.now();
    return SolvedSnapshot(
      date: dateKey(fetchedAt),
      fetchedAt: fetchedAt,
      ojId: result.ojId,
      username: result.username,
      status: result.status,
      solvedCount: result.solvedCount,
      error: result.error,
    );
  }

  factory SolvedSnapshot.fromJson(Map<String, dynamic> json) {
    final snapshot = SolvedSnapshot.tryFromJson(json);
    if (snapshot == null) {
      throw const FormatException('Invalid solved snapshot JSON.');
    }
    return snapshot;
  }

  static SolvedSnapshot? tryFromJson(Map<String, dynamic> json) {
    final date = json['date'];
    final fetchedAt = json['fetchedAt'];
    final ojId = json['ojId'];
    final username = json['username'];
    final status = json['status'];
    final solvedCount = json['solvedCount'];
    final error = json['error'];

    if (date is! String || !_isValidDateKey(date)) {
      return null;
    }
    if (fetchedAt is! String) {
      return null;
    }
    final parsedFetchedAt = DateTime.tryParse(fetchedAt);
    if (parsedFetchedAt == null) {
      return null;
    }
    if (ojId is! String || ojId.isEmpty) {
      return null;
    }
    if (status is! String) {
      return null;
    }
    final parsedStatus = _parseFetchStatus(status);
    if (parsedStatus == null) {
      return null;
    }
    if (username != null && username is! String) {
      return null;
    }
    if (solvedCount != null && solvedCount is! int) {
      return null;
    }
    if (error != null && error is! String) {
      return null;
    }

    return SolvedSnapshot(
      date: date,
      fetchedAt: parsedFetchedAt,
      ojId: ojId,
      username: username as String? ?? '',
      status: parsedStatus,
      solvedCount: solvedCount as int?,
      error: error as String?,
    );
  }

  static FetchStatus? _parseFetchStatus(String value) {
    for (final status in FetchStatus.values) {
      if (status.name == value) {
        return status;
      }
    }
    return null;
  }

  static bool _isValidDateKey(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) {
      return false;
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day;
  }

  final String date;
  final DateTime fetchedAt;
  final String ojId;
  final String username;
  final FetchStatus status;
  final int? solvedCount;
  final String? error;

  Map<String, dynamic> toJson() => {
        'date': date,
        'fetchedAt': fetchedAt.toIso8601String(),
        'ojId': ojId,
        'username': username,
        'status': status.name,
        'solvedCount': solvedCount,
        'error': error,
      };
}
