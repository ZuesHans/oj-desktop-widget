// ignore_for_file: constant_identifier_names

import 'dart:convert';

import '../core/time.dart';

enum ProblemStatus { AC, WA, TLE, RE, REVIEW, TODO }

enum ProblemPlatform { cf, atcoder, hd, lg, poj, uva, nc, spoj, lccn, other }

class ProblemRecord {
  const ProblemRecord({
    required this.id,
    required this.title,
    required this.url,
    required this.platform,
    required this.status,
    required this.tags,
    required this.date,
    required this.note,
    required this.analysis,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProblemRecord.create({
    String? id,
    required String title,
    required String url,
    required ProblemPlatform platform,
    ProblemStatus status = ProblemStatus.TODO,
    List<String> tags = const [],
    DateTime? now,
    String? date,
    String note = '',
    String analysis = '',
  }) {
    final timestamp = now ?? DateTime.now();
    return ProblemRecord(
      id: id ?? buildProblemId(timestamp),
      title: title.trim(),
      url: url.trim(),
      platform: platform,
      status: status,
      tags: normalizeProblemTags(tags),
      date: date ?? dateKey(timestamp),
      note: note.trim(),
      analysis: analysis.trim(),
      createdAt: timestamp,
      updatedAt: timestamp,
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
    if (date is! String || !_isValidDateKey(date)) {
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
    final status = parseProblemStatus(json['status']);
    if (platform == null || status == null) {
      return null;
    }
    final tags = parseProblemTags(json['tags']);
    if (tags == null) {
      return null;
    }

    return ProblemRecord(
      id: id.trim(),
      title: title.trim(),
      url: url.trim(),
      platform: platform,
      status: status,
      tags: tags,
      date: date,
      note: (note as String?)?.trim() ?? '',
      analysis: (analysis as String?)?.trim() ?? '',
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  final String id;
  final String title;
  final String url;
  final ProblemPlatform platform;
  final ProblemStatus status;
  final List<String> tags;
  final String date;
  final String note;
  final String analysis;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProblemRecord copyWith({
    String? title,
    String? url,
    ProblemPlatform? platform,
    ProblemStatus? status,
    List<String>? tags,
    String? date,
    String? note,
    String? analysis,
    DateTime? updatedAt,
  }) {
    return ProblemRecord(
      id: id,
      title: title?.trim() ?? this.title,
      url: url?.trim() ?? this.url,
      platform: platform ?? this.platform,
      status: status ?? this.status,
      tags: tags == null ? this.tags : normalizeProblemTags(tags),
      date: date ?? this.date,
      note: note?.trim() ?? this.note,
      analysis: analysis?.trim() ?? this.analysis,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'url': url,
        'platform': problemPlatformValue(platform),
        'status': status.name,
        'tags': tags,
        'date': date,
        'note': note,
        'analysis': analysis,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  Map<String, dynamic> toStorageJson() => {
        ...toJson(),
        'tags': jsonEncode(tags),
      };

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
      return ProblemPlatform.lg;
    case 'poj':
      return ProblemPlatform.poj;
    case 'uva':
      return ProblemPlatform.uva;
    case 'nc':
    case 'nowcoder':
    case '牛客':
      return ProblemPlatform.nc;
    case 'spoj':
      return ProblemPlatform.spoj;
    case 'lccn':
    case 'leetcode':
    case 'leetcodecn':
    case 'leetcode.cn':
      return ProblemPlatform.lccn;
    case 'other':
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
      return 'Other';
  }
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
