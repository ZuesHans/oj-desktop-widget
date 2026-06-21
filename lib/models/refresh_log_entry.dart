enum RefreshLogStatus { success, failure, blocked, fallbackSuccess }

class RefreshLogEntry {
  const RefreshLogEntry({
    required this.id,
    required this.fetchedAt,
    required this.ojId,
    required this.username,
    required this.status,
    required this.source,
    required this.message,
    this.solvedCount,
    this.previousSolvedCount,
  });

  factory RefreshLogEntry.create({
    required DateTime fetchedAt,
    required String ojId,
    required String username,
    required RefreshLogStatus status,
    required String source,
    required String message,
    int? solvedCount,
    int? previousSolvedCount,
  }) {
    return RefreshLogEntry(
      id: buildRefreshLogId(fetchedAt, ojId, username),
      fetchedAt: fetchedAt,
      ojId: ojId,
      username: username,
      status: status,
      source: source,
      message: message.trim(),
      solvedCount: solvedCount,
      previousSolvedCount: previousSolvedCount,
    );
  }

  factory RefreshLogEntry.fromJson(Map<String, dynamic> json) {
    final entry = RefreshLogEntry.tryFromJson(json);
    if (entry == null) {
      throw const FormatException('Invalid refresh log JSON.');
    }
    return entry;
  }

  static RefreshLogEntry? tryFromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final fetchedAt = json['fetchedAt'];
    final ojId = json['ojId'];
    final username = json['username'];
    final status = json['status'];
    final source = json['source'];
    final message = json['message'];
    final solvedCount = json['solvedCount'];
    final previousSolvedCount = json['previousSolvedCount'];

    if (id is! String || id.trim().isEmpty) {
      return null;
    }
    if (fetchedAt is! String) {
      return null;
    }
    final parsedFetchedAt = DateTime.tryParse(fetchedAt);
    if (parsedFetchedAt == null) {
      return null;
    }
    if (ojId is! String || ojId.trim().isEmpty) {
      return null;
    }
    if (username is! String) {
      return null;
    }
    if (status is! String) {
      return null;
    }
    final parsedStatus = parseRefreshLogStatus(status);
    if (parsedStatus == null) {
      return null;
    }
    if (source is! String || source.trim().isEmpty) {
      return null;
    }
    if (message is! String) {
      return null;
    }
    if (solvedCount != null && solvedCount is! int) {
      return null;
    }
    if (previousSolvedCount != null && previousSolvedCount is! int) {
      return null;
    }

    return RefreshLogEntry(
      id: id.trim(),
      fetchedAt: parsedFetchedAt,
      ojId: ojId.trim(),
      username: username,
      status: parsedStatus,
      source: source.trim(),
      message: message.trim(),
      solvedCount: solvedCount as int?,
      previousSolvedCount: previousSolvedCount as int?,
    );
  }

  final String id;
  final DateTime fetchedAt;
  final String ojId;
  final String username;
  final RefreshLogStatus status;
  final String source;
  final int? solvedCount;
  final int? previousSolvedCount;
  final String message;

  Map<String, dynamic> toJson() => {
        'id': id,
        'fetchedAt': fetchedAt.toIso8601String(),
        'ojId': ojId,
        'username': username,
        'status': status.name,
        'source': source,
        'solvedCount': solvedCount,
        'previousSolvedCount': previousSolvedCount,
        'message': message,
      };
}

RefreshLogStatus? parseRefreshLogStatus(String value) {
  for (final status in RefreshLogStatus.values) {
    if (status.name == value) {
      return status;
    }
  }
  return null;
}

String buildRefreshLogId(DateTime fetchedAt, String ojId, String username) {
  final micros = fetchedAt.microsecondsSinceEpoch.toRadixString(36);
  final safeOj = ojId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  final safeUser = username.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  return 'r${micros}_${safeOj}_$safeUser';
}
