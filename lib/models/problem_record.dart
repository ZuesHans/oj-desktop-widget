// ignore_for_file: constant_identifier_names

import 'dart:convert';

import '../core/time.dart';

enum ProblemStatus { AC, WA, TLE, RE, REVIEW, TODO }

enum ProblemWorkflowStatus { backlog, active, review, mastered, archived }

enum ProblemPlatform { cf, atcoder, hd, lg, poj, uva, nc, spoj, lccn, other }

class ProblemRecord {
  factory ProblemRecord({
    required String id,
    required String title,
    required String url,
    required ProblemPlatform platform,
    ProblemStatus? status,
    ProblemWorkflowStatus? workflowStatus,
    required List<String> tags,
    required String date,
    required String note,
    required String analysis,
    required DateTime createdAt,
    required DateTime updatedAt,
    String difficulty = '',
    String externalId = '',
    int reviewStage = 0,
    DateTime? nextReviewAt,
    DateTime? archivedAt,
    bool isFavorite = false,
    bool isPinned = false,
    DateTime? lastOpenedAt,
  }) {
    final legacyStatus = status ?? ProblemStatus.TODO;
    return ProblemRecord._(
      id: id,
      title: title,
      url: url,
      platform: platform,
      workflowStatus:
          workflowStatus ?? problemWorkflowStatusFromLegacy(legacyStatus),
      tags: tags,
      date: date,
      note: note,
      analysis: analysis,
      difficulty: difficulty,
      externalId: externalId,
      reviewStage: reviewStage.clamp(0, 5).toInt(),
      nextReviewAt: nextReviewAt,
      archivedAt: archivedAt,
      isFavorite: isFavorite,
      isPinned: isPinned,
      lastOpenedAt: lastOpenedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      legacyStatusForMigration: workflowStatus == null ? legacyStatus : null,
    );
  }

  const ProblemRecord._({
    required this.id,
    required this.title,
    required this.url,
    required this.platform,
    required this.workflowStatus,
    required this.tags,
    required this.date,
    required this.note,
    required this.analysis,
    required this.difficulty,
    required this.externalId,
    required this.reviewStage,
    required this.nextReviewAt,
    required this.archivedAt,
    required this.isFavorite,
    required this.isPinned,
    required this.lastOpenedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.legacyStatusForMigration,
  });

  factory ProblemRecord.create({
    String? id,
    required String title,
    required String url,
    required ProblemPlatform platform,
    ProblemStatus? status,
    ProblemWorkflowStatus? workflowStatus,
    List<String> tags = const [],
    DateTime? now,
    String? date,
    String note = '',
    String analysis = '',
    String difficulty = '',
    String externalId = '',
  }) {
    final timestamp = now ?? DateTime.now();
    final legacyStatus = status ?? ProblemStatus.TODO;
    return ProblemRecord._(
      id: id ?? buildProblemId(timestamp),
      title: title.trim(),
      url: url.trim(),
      platform: platform,
      workflowStatus:
          workflowStatus ?? problemWorkflowStatusFromLegacy(legacyStatus),
      tags: normalizeProblemTags(tags),
      date: date ?? dateKey(timestamp),
      note: note.trim(),
      analysis: analysis.trim(),
      difficulty: difficulty.trim(),
      externalId: externalId.trim(),
      reviewStage: 0,
      nextReviewAt: null,
      archivedAt: null,
      isFavorite: false,
      isPinned: false,
      lastOpenedAt: null,
      createdAt: timestamp,
      updatedAt: timestamp,
      legacyStatusForMigration: workflowStatus == null ? legacyStatus : null,
    );
  }

  factory ProblemRecord.fromJson(Map<String, dynamic> json) {
    final record = ProblemRecord.tryFromJson(json);
    if (record == null) {
      throw const FormatException('Invalid problem JSON.');
    }
    return record;
  }

  static ProblemRecord? tryFromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final url = json['url'];
    final date = json['date'];
    final note = json['note'];
    final analysis = json['analysis'];
    final createdAt = json['created_at'] ?? json['createdAt'];
    final updatedAt = json['updated_at'] ?? json['updatedAt'];
    if (id is! String || id.trim().isEmpty) {
      return null;
    }
    if (title is! String || title.trim().isEmpty) {
      return null;
    }
    if (url is! String || url.trim().isEmpty) {
      return null;
    }
    if (date is! String || !isValidDateKey(date)) {
      return null;
    }
    if (note != null && note is! String) {
      return null;
    }
    if (analysis != null && analysis is! String) {
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
    final platform = parseProblemPlatform(json['platform']);
    final legacyStatus = parseProblemStatus(json['status']);
    final workflowStatus = parseProblemWorkflowStatus(json['workflowStatus']) ??
        (legacyStatus == null
            ? null
            : problemWorkflowStatusFromLegacy(legacyStatus));
    if (platform == null || workflowStatus == null) {
      return null;
    }
    final tags = parseProblemTags(json['tags']);
    if (tags == null) {
      return null;
    }

    final reviewStage = json['reviewStage'];
    if (reviewStage != null &&
        (reviewStage is! int || reviewStage < 0 || reviewStage > 5)) {
      return null;
    }
    final nextReviewAt = json['nextReviewAt'];
    final parsedNextReviewAt =
        nextReviewAt is String ? DateTime.tryParse(nextReviewAt) : null;
    if (nextReviewAt != null && parsedNextReviewAt == null) {
      return null;
    }
    final archivedAt = json['archivedAt'];
    final lastOpenedAt = json['lastOpenedAt'];
    final parsedLastOpenedAt = lastOpenedAt is String ? DateTime.tryParse(lastOpenedAt) : null;
    if (lastOpenedAt != null && parsedLastOpenedAt == null) return null;
    final parsedArchivedAt =
        archivedAt is String ? DateTime.tryParse(archivedAt) : null;
    if (archivedAt != null && parsedArchivedAt == null) {
      return null;
    }

    return ProblemRecord._(
      id: id.trim(),
      title: title.trim(),
      url: url.trim(),
      platform: platform,
      workflowStatus: workflowStatus,
      tags: tags,
      date: date,
      note: (note as String?)?.trim() ?? '',
      analysis: (analysis as String?)?.trim() ?? '',
      difficulty: json['difficulty'] is String
          ? (json['difficulty'] as String).trim()
          : '',
      externalId: json['externalId'] is String
          ? (json['externalId'] as String).trim()
          : '',
      reviewStage: reviewStage is int ? reviewStage : 0,
      nextReviewAt: parsedNextReviewAt,
      archivedAt: parsedArchivedAt,
      isFavorite: json['isFavorite'] == true,
      isPinned: json['isPinned'] == true,
      lastOpenedAt: parsedLastOpenedAt,
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
      legacyStatusForMigration:
          json['workflowStatus'] == null ? legacyStatus : null,
    );
  }

  final String id;
  final String title;
  final String url;
  final ProblemPlatform platform;
  final ProblemWorkflowStatus workflowStatus;
  final List<String> tags;
  final String date;
  final String note;
  final String analysis;
  final String difficulty;
  final String externalId;
  final int reviewStage;
  final DateTime? nextReviewAt;
  final DateTime? archivedAt;
  final bool isFavorite;
  final bool isPinned;
  final DateTime? lastOpenedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ProblemStatus? legacyStatusForMigration;

  ProblemStatus get status => legacyProblemStatusForWorkflow(workflowStatus);

  ProblemRecord copyWith({
    String? title,
    String? url,
    ProblemPlatform? platform,
    ProblemStatus? status,
    ProblemWorkflowStatus? workflowStatus,
    List<String>? tags,
    String? date,
    String? note,
    String? analysis,
    String? difficulty,
    String? externalId,
    int? reviewStage,
    DateTime? nextReviewAt,
    bool clearNextReviewAt = false,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
    bool? isFavorite,
    bool? isPinned,
    DateTime? lastOpenedAt,
    bool clearLastOpenedAt = false,
    DateTime? updatedAt,
  }) {
    return ProblemRecord._(
      id: id,
      title: title?.trim() ?? this.title,
      url: url?.trim() ?? this.url,
      platform: platform ?? this.platform,
      workflowStatus: workflowStatus ??
          (status == null
              ? this.workflowStatus
              : problemWorkflowStatusFromLegacy(status)),
      tags: tags == null ? this.tags : normalizeProblemTags(tags),
      date: date ?? this.date,
      note: note?.trim() ?? this.note,
      analysis: analysis?.trim() ?? this.analysis,
      difficulty: difficulty?.trim() ?? this.difficulty,
      externalId: externalId?.trim() ?? this.externalId,
      reviewStage: (reviewStage ?? this.reviewStage).clamp(0, 5).toInt(),
      nextReviewAt:
          clearNextReviewAt ? null : nextReviewAt ?? this.nextReviewAt,
      archivedAt: clearArchivedAt ? null : archivedAt ?? this.archivedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      isPinned: isPinned ?? this.isPinned,
      lastOpenedAt: clearLastOpenedAt ? null : lastOpenedAt ?? this.lastOpenedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      legacyStatusForMigration: null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'platform': problemPlatformValue(platform),
        'status': status.name,
        'workflowStatus': workflowStatus.name,
        'tags': tags,
        'date': date,
        'note': note,
        'analysis': analysis,
        'difficulty': difficulty,
        'externalId': externalId,
        'archivedAt': archivedAt?.toIso8601String(),
        'isFavorite': isFavorite,
        'isPinned': isPinned,
        'lastOpenedAt': lastOpenedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Map<String, dynamic> toStorageJson() => {
        ...toJson(),
        'tags': jsonEncode(tags),
      };
}

ProblemWorkflowStatus problemWorkflowStatusFromLegacy(ProblemStatus status) {
  return switch (status) {
    ProblemStatus.AC => ProblemWorkflowStatus.mastered,
    ProblemStatus.REVIEW => ProblemWorkflowStatus.review,
    ProblemStatus.TODO => ProblemWorkflowStatus.backlog,
    ProblemStatus.WA ||
    ProblemStatus.TLE ||
    ProblemStatus.RE =>
      ProblemWorkflowStatus.active,
  };
}

ProblemStatus legacyProblemStatusForWorkflow(ProblemWorkflowStatus status) {
  return switch (status) {
    ProblemWorkflowStatus.backlog => ProblemStatus.TODO,
    ProblemWorkflowStatus.active => ProblemStatus.TODO,
    ProblemWorkflowStatus.review => ProblemStatus.REVIEW,
    ProblemWorkflowStatus.mastered => ProblemStatus.AC,
    ProblemWorkflowStatus.archived => ProblemStatus.AC,
  };
}

ProblemWorkflowStatus? parseProblemWorkflowStatus(Object? value) {
  if (value is! String) {
    return null;
  }
  for (final status in ProblemWorkflowStatus.values) {
    if (status.name == value.trim()) {
      return status;
    }
  }
  return null;
}

ProblemStatus? parseProblemStatus(Object? value) {
  if (value is! String) {
    return null;
  }
  final normalized = value.trim().toUpperCase();
  for (final status in ProblemStatus.values) {
    if (status.name == normalized) {
      return status;
    }
  }
  return null;
}

ProblemPlatform? parseProblemPlatform(Object? value) {
  if (value is! String) {
    return null;
  }
  final normalized = value.trim().toLowerCase();
  switch (normalized) {
    case 'cf':
    case 'codeforces':
      return ProblemPlatform.cf;
    case 'atcoder':
    case 'at':
      return ProblemPlatform.atcoder;
    case 'hd':
    case 'hdu':
      return ProblemPlatform.hd;
    case 'lg':
    case 'luogu':
    case '洛谷':
    // Keep old mojibake aliases readable only as import compatibility.
    case '娲涜胺':
      return ProblemPlatform.lg;
    case 'poj':
      return ProblemPlatform.poj;
    case 'uva':
      return ProblemPlatform.uva;
    case 'nc':
    case 'nowcoder':
    case '牛客':
    // Keep old mojibake aliases readable only as import compatibility.
    case '鐗涘':
      return ProblemPlatform.nc;
    case 'spoj':
      return ProblemPlatform.spoj;
    case 'lccn':
    case 'leetcode':
    case 'leetcodecn':
    case 'leetcode.cn':
      return ProblemPlatform.lccn;
    case 'other':
    // Keep old mojibake aliases readable only as import compatibility.
    case '鍏朵粬':
      return ProblemPlatform.other;
  }
  return null;
}

String problemPlatformValue(ProblemPlatform platform) => platform.name;

String problemPlatformLabel(ProblemPlatform platform) {
  switch (platform) {
    case ProblemPlatform.cf:
      return 'Codeforces';
    case ProblemPlatform.atcoder:
      return 'AtCoder';
    case ProblemPlatform.hd:
      return 'HDU';
    case ProblemPlatform.lg:
      return '洛谷';
    case ProblemPlatform.poj:
      return 'POJ';
    case ProblemPlatform.uva:
      return 'UVA';
    case ProblemPlatform.nc:
      return '牛客';
    case ProblemPlatform.spoj:
      return 'SPOJ';
    case ProblemPlatform.lccn:
      return 'LeetCode CN';
    case ProblemPlatform.other:
      return '其他';
  }
}

String problemStatusLabel(ProblemStatus status) {
  switch (status) {
    case ProblemStatus.AC:
      return '已通过';
    case ProblemStatus.WA:
      return '答案错误';
    case ProblemStatus.TLE:
      return '超时';
    case ProblemStatus.RE:
      return '运行错误';
    case ProblemStatus.REVIEW:
      return '复盘中';
    case ProblemStatus.TODO:
      return '待做';
  }
}

String problemWorkflowStatusLabel(ProblemWorkflowStatus status) {
  return switch (status) {
    ProblemWorkflowStatus.backlog => '待安排',
    ProblemWorkflowStatus.active => '训练中',
    ProblemWorkflowStatus.review => '待复习',
    ProblemWorkflowStatus.mastered => '已掌握',
    ProblemWorkflowStatus.archived => '已归档',
  };
}

List<String>? parseProblemTags(Object? value) {
  if (value == null) {
    return const [];
  }
  if (value is List) {
    return normalizeProblemTags(value.whereType<String>());
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return normalizeProblemTags(decoded.whereType<String>());
      }
    } catch (_) {
      return normalizeProblemTags(trimmed.split(','));
    }
  }
  return null;
}

List<String> normalizeProblemTags(Iterable<String> values) {
  final seen = <String>{};
  final tags = <String>[];
  for (final value in values) {
    for (final part in value.split(',')) {
      final tag = part.trim();
      if (tag.isNotEmpty && seen.add(tag.toLowerCase())) {
        tags.add(tag);
      }
    }
  }
  return List.unmodifiable(tags);
}

String buildProblemId(DateTime time) {
  final micros = time.microsecondsSinceEpoch.toRadixString(36);
  return 'p$micros';
}

