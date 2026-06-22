import '../core/time.dart';

class ContestRecord {
  const ContestRecord({
    required this.id,
    required this.title,
    required this.date,
    required this.rank,
    required this.totalParticipants,
    required this.solvedCount,
    required this.penalty,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ContestRecord.create({
    String? id,
    required String title,
    required String date,
    required int rank,
    int? totalParticipants,
    int? solvedCount,
    int? penalty,
    String note = '',
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return ContestRecord(
      id: id ?? buildContestRecordId(timestamp),
      title: title.trim(),
      date: date,
      rank: rank,
      totalParticipants: totalParticipants,
      solvedCount: solvedCount,
      penalty: penalty,
      note: note.trim(),
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  factory ContestRecord.fromJson(Map<String, dynamic> json) {
    final record = ContestRecord.tryFromJson(json);
    if (record == null) {
      throw const FormatException('Invalid contest record JSON.');
    }
    return record;
  }

  static ContestRecord? tryFromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final date = json['date'];
    final rank = _parseInt(json['rank']);
    final totalParticipants = _parseOptionalInt(json['totalParticipants']);
    final solvedCount = _parseOptionalInt(json['solvedCount']);
    final penalty = _parseOptionalInt(json['penalty']);
    final note = json['note'];
    final createdAt = json['created_at'] ?? json['createdAt'];
    final updatedAt = json['updated_at'] ?? json['updatedAt'];

    if (id is! String || id.trim().isEmpty) {
      return null;
    }
    if (title is! String || title.trim().isEmpty) {
      return null;
    }
    if (date is! String || !isValidDateKey(date)) {
      return null;
    }
    if (rank == null || rank <= 0) {
      return null;
    }
    if (totalParticipants != null &&
        (totalParticipants <= 0 || totalParticipants < rank)) {
      return null;
    }
    if (solvedCount != null && solvedCount < 0) {
      return null;
    }
    if (penalty != null && penalty < 0) {
      return null;
    }
    if (note != null && note is! String) {
      return null;
    }
    if (createdAt is! String || updatedAt is! String) {
      return null;
    }
    final parsedCreatedAt = DateTime.tryParse(createdAt);
    final parsedUpdatedAt = DateTime.tryParse(updatedAt);
    if (parsedCreatedAt == null || parsedUpdatedAt == null) {
      return null;
    }

    return ContestRecord(
      id: id.trim(),
      title: title.trim(),
      date: date,
      rank: rank,
      totalParticipants: totalParticipants,
      solvedCount: solvedCount,
      penalty: penalty,
      note: (note as String?)?.trim() ?? '',
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  final String id;
  final String title;
  final String date;
  final int rank;
  final int? totalParticipants;
  final int? solvedCount;
  final int? penalty;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;

  ContestRecord copyWith({
    String? title,
    String? date,
    int? rank,
    int? totalParticipants,
    bool clearTotalParticipants = false,
    int? solvedCount,
    bool clearSolvedCount = false,
    int? penalty,
    bool clearPenalty = false,
    String? note,
    DateTime? updatedAt,
  }) {
    return ContestRecord(
      id: id,
      title: title?.trim() ?? this.title,
      date: date ?? this.date,
      rank: rank ?? this.rank,
      totalParticipants: clearTotalParticipants
          ? null
          : totalParticipants ?? this.totalParticipants,
      solvedCount: clearSolvedCount ? null : solvedCount ?? this.solvedCount,
      penalty: clearPenalty ? null : penalty ?? this.penalty,
      note: note?.trim() ?? this.note,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'date': date,
        'rank': rank,
        'totalParticipants': totalParticipants,
        'solvedCount': solvedCount,
        'penalty': penalty,
        'note': note,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Map<String, dynamic> toStorageJson() => toJson();
}

class ContestRankPoint {
  const ContestRankPoint({
    required this.record,
    required this.date,
    required this.rank,
  });

  final ContestRecord record;
  final DateTime date;
  final int rank;
}

String buildContestRecordId(DateTime time) {
  final micros = time.microsecondsSinceEpoch.toRadixString(36);
  return 'c$micros';
}

int? _parseOptionalInt(Object? value) {
  if (value == null) {
    return null;
  }
  return _parseInt(value);
}

int? _parseInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num && value % 1 == 0) {
    return value.toInt();
  }
  if (value is String && value.trim().isNotEmpty) {
    return int.tryParse(value.trim());
  }
  return null;
}

String defaultContestDate() => dateKey(DateTime.now());
