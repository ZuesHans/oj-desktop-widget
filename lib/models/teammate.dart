import '../core/oj_catalog.dart';
import '../core/time.dart';

const maxTeammates = 3;
const teammateHistoryDays = 7;

class TeammateProfile {
  const TeammateProfile({
    required this.id,
    required this.nickname,
    required this.accounts,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TeammateProfile.create({
    String? id,
    required String nickname,
    required List<TeammateAccount> accounts,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    return TeammateProfile(
      id: id ?? buildTeammateId(timestamp),
      nickname: nickname.trim(),
      accounts: normalizeTeammateAccounts(accounts),
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  factory TeammateProfile.fromJson(Map<String, dynamic> json) {
    final profile = TeammateProfile.tryFromJson(json);
    if (profile == null) {
      throw const FormatException('Invalid teammate profile JSON.');
    }
    return profile;
  }

  static TeammateProfile? tryFromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final nickname = json['nickname'];
    final rawAccounts = json['accounts'];
    final createdAt = json['created_at'] ?? json['createdAt'];
    final updatedAt = json['updated_at'] ?? json['updatedAt'];
    if (id is! String || id.trim().isEmpty) {
      return null;
    }
    if (nickname is! String || nickname.trim().isEmpty) {
      return null;
    }
    if (rawAccounts is! List) {
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
    final accounts = <TeammateAccount>[];
    for (final item in rawAccounts) {
      if (item is! Map) {
        continue;
      }
      final account = TeammateAccount.tryFromJson(
        Map<String, dynamic>.from(item),
      );
      if (account != null) {
        accounts.add(account);
      }
    }
    final normalizedAccounts = normalizeTeammateAccounts(accounts);
    if (!normalizedAccounts.any((account) => account.enabled)) {
      return null;
    }
    return TeammateProfile(
      id: id.trim(),
      nickname: nickname.trim(),
      accounts: normalizedAccounts,
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  final String id;
  final String nickname;
  final List<TeammateAccount> accounts;
  final DateTime createdAt;
  final DateTime updatedAt;

  TeammateProfile copyWith({
    String? nickname,
    List<TeammateAccount>? accounts,
    DateTime? updatedAt,
  }) {
    return TeammateProfile(
      id: id,
      nickname: nickname?.trim() ?? this.nickname,
      accounts: accounts == null
          ? this.accounts
          : normalizeTeammateAccounts(accounts),
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nickname': nickname,
        'accounts': accounts.map((account) => account.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}

class TeammateAccount {
  const TeammateAccount({
    required this.platform,
    required this.handle,
    this.enabled = true,
  });

  factory TeammateAccount.fromJson(Map<String, dynamic> json) {
    final account = TeammateAccount.tryFromJson(json);
    if (account == null) {
      throw const FormatException('Invalid teammate account JSON.');
    }
    return account;
  }

  static TeammateAccount? tryFromJson(Map<String, dynamic> json) {
    final platform = json['platform'] ?? json['ojId'];
    final handle = json['handle'] ?? json['username'] ?? json['uid'];
    final enabled = json['enabled'];
    if (platform is! String || !isSupportedOjId(platform)) {
      return null;
    }
    if (handle is! String || handle.trim().isEmpty) {
      return null;
    }
    return TeammateAccount(
      platform: platform,
      handle: handle.trim(),
      enabled: enabled is bool ? enabled : true,
    );
  }

  final String platform;
  final String handle;
  final bool enabled;

  TeammateAccount copyWith({
    String? platform,
    String? handle,
    bool? enabled,
  }) {
    return TeammateAccount(
      platform: platform ?? this.platform,
      handle: handle?.trim() ?? this.handle,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'platform': platform,
        'handle': handle,
        'enabled': enabled,
      };
}

class TeammateDailyRecord {
  const TeammateDailyRecord({
    required this.teammateId,
    required this.trainingDate,
    required this.perPlatformDelta,
    required this.totalDelta,
    required this.refreshedAt,
    this.errors = const {},
  });

  factory TeammateDailyRecord.fromJson(Map<String, dynamic> json) {
    final record = TeammateDailyRecord.tryFromJson(json);
    if (record == null) {
      throw const FormatException('Invalid teammate daily record JSON.');
    }
    return record;
  }

  static TeammateDailyRecord? tryFromJson(Map<String, dynamic> json) {
    final teammateId = json['teammateId'];
    final trainingDate = json['trainingDate'];
    final rawDeltas = json['perPlatformDelta'];
    final totalDelta = _parseInt(json['totalDelta']);
    final refreshedAt = json['refreshedAt'];
    final rawErrors = json['errors'];
    if (teammateId is! String || teammateId.trim().isEmpty) {
      return null;
    }
    if (trainingDate is! String || !isValidDateKey(trainingDate)) {
      return null;
    }
    if (rawDeltas is! Map) {
      return null;
    }
    if (totalDelta == null || totalDelta < 0) {
      return null;
    }
    if (refreshedAt is! String) {
      return null;
    }
    final parsedRefreshedAt = DateTime.tryParse(refreshedAt);
    if (parsedRefreshedAt == null) {
      return null;
    }
    final deltas = <String, int>{};
    for (final entry in rawDeltas.entries) {
      if (entry.key is! String || !isSupportedOjId(entry.key as String)) {
        continue;
      }
      final delta = _parseInt(entry.value);
      if (delta != null && delta >= 0) {
        deltas[entry.key as String] = delta;
      }
    }
    final errors = <String, String>{};
    if (rawErrors is Map) {
      for (final entry in rawErrors.entries) {
        if (entry.key is String &&
            isSupportedOjId(entry.key as String) &&
            entry.value is String &&
            (entry.value as String).trim().isNotEmpty) {
          errors[entry.key as String] = (entry.value as String).trim();
        }
      }
    }
    return TeammateDailyRecord(
      teammateId: teammateId.trim(),
      trainingDate: trainingDate,
      perPlatformDelta: Map.unmodifiable(deltas),
      totalDelta: totalDelta,
      refreshedAt: parsedRefreshedAt,
      errors: Map.unmodifiable(errors),
    );
  }

  final String teammateId;
  final String trainingDate;
  final Map<String, int> perPlatformDelta;
  final int totalDelta;
  final DateTime refreshedAt;
  final Map<String, String> errors;

  Map<String, dynamic> toJson() => {
        'teammateId': teammateId,
        'trainingDate': trainingDate,
        'perPlatformDelta': perPlatformDelta,
        'totalDelta': totalDelta,
        'refreshedAt': refreshedAt.toIso8601String(),
        'errors': errors,
      };
}

class TeammateSolvedSnapshot {
  const TeammateSolvedSnapshot({
    required this.teammateId,
    required this.platform,
    required this.trainingDate,
    required this.solvedTotalAtStart,
    required this.latestSolvedTotal,
    required this.updatedAt,
  });

  factory TeammateSolvedSnapshot.fromJson(Map<String, dynamic> json) {
    final snapshot = TeammateSolvedSnapshot.tryFromJson(json);
    if (snapshot == null) {
      throw const FormatException('Invalid teammate snapshot JSON.');
    }
    return snapshot;
  }

  static TeammateSolvedSnapshot? tryFromJson(Map<String, dynamic> json) {
    final teammateId = json['teammateId'];
    final platform = json['platform'];
    final trainingDate = json['trainingDate'];
    final solvedTotalAtStart = _parseInt(json['solvedTotalAtStart']);
    final latestSolvedTotal = _parseInt(json['latestSolvedTotal']);
    final updatedAt = json['updatedAt'] ?? json['updated_at'];
    if (teammateId is! String || teammateId.trim().isEmpty) {
      return null;
    }
    if (platform is! String || !isSupportedOjId(platform)) {
      return null;
    }
    if (trainingDate is! String || !isValidDateKey(trainingDate)) {
      return null;
    }
    if (solvedTotalAtStart == null || solvedTotalAtStart < 0) {
      return null;
    }
    if (latestSolvedTotal == null || latestSolvedTotal < 0) {
      return null;
    }
    if (updatedAt is! String) {
      return null;
    }
    final parsedUpdatedAt = DateTime.tryParse(updatedAt);
    if (parsedUpdatedAt == null) {
      return null;
    }
    return TeammateSolvedSnapshot(
      teammateId: teammateId.trim(),
      platform: platform,
      trainingDate: trainingDate,
      solvedTotalAtStart: solvedTotalAtStart,
      latestSolvedTotal: latestSolvedTotal,
      updatedAt: parsedUpdatedAt,
    );
  }

  final String teammateId;
  final String platform;
  final String trainingDate;
  final int solvedTotalAtStart;
  final int latestSolvedTotal;
  final DateTime updatedAt;

  TeammateSolvedSnapshot copyWith({
    int? solvedTotalAtStart,
    int? latestSolvedTotal,
    DateTime? updatedAt,
  }) {
    return TeammateSolvedSnapshot(
      teammateId: teammateId,
      platform: platform,
      trainingDate: trainingDate,
      solvedTotalAtStart: solvedTotalAtStart ?? this.solvedTotalAtStart,
      latestSolvedTotal: latestSolvedTotal ?? this.latestSolvedTotal,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'teammateId': teammateId,
        'platform': platform,
        'trainingDate': trainingDate,
        'solvedTotalAtStart': solvedTotalAtStart,
        'latestSolvedTotal': latestSolvedTotal,
        'updatedAt': updatedAt.toIso8601String(),
      };
}

class TeammateStoreData {
  const TeammateStoreData({
    this.profiles = const [],
    this.records = const [],
    this.snapshots = const [],
    this.lastAutoRefreshTrainingDate,
  });

  factory TeammateStoreData.fromJson(Map<String, dynamic> json) {
    final data = TeammateStoreData.tryFromJson(json);
    if (data == null) {
      throw const FormatException('Invalid teammate data JSON.');
    }
    return data;
  }

  static TeammateStoreData? tryFromJson(Map<String, dynamic> json) {
    final rawProfiles = json['profiles'];
    final rawRecords = json['records'] ?? json['dailyRecords'];
    final rawSnapshots = json['snapshots'];
    final lastAutoRefreshTrainingDate = json['lastAutoRefreshTrainingDate'];
    if (rawProfiles != null && rawProfiles is! List) {
      return null;
    }
    if (rawRecords != null && rawRecords is! List) {
      return null;
    }
    if (rawSnapshots != null && rawSnapshots is! List) {
      return null;
    }
    if (lastAutoRefreshTrainingDate != null &&
        (lastAutoRefreshTrainingDate is! String ||
            !isValidDateKey(lastAutoRefreshTrainingDate))) {
      return null;
    }

    final profiles = <TeammateProfile>[];
    for (final item in rawProfiles ?? const []) {
      if (item is! Map || profiles.length >= maxTeammates) {
        continue;
      }
      final profile = TeammateProfile.tryFromJson(
        Map<String, dynamic>.from(item),
      );
      if (profile != null && !profiles.any((entry) => entry.id == profile.id)) {
        profiles.add(profile);
      }
    }
    final teammateIds = profiles.map((profile) => profile.id).toSet();

    final records = <TeammateDailyRecord>[];
    for (final item in rawRecords ?? const []) {
      if (item is! Map) {
        continue;
      }
      final record = TeammateDailyRecord.tryFromJson(
        Map<String, dynamic>.from(item),
      );
      if (record != null && teammateIds.contains(record.teammateId)) {
        records.add(record);
      }
    }

    final snapshots = <TeammateSolvedSnapshot>[];
    for (final item in rawSnapshots ?? const []) {
      if (item is! Map) {
        continue;
      }
      final snapshot = TeammateSolvedSnapshot.tryFromJson(
        Map<String, dynamic>.from(item),
      );
      if (snapshot != null && teammateIds.contains(snapshot.teammateId)) {
        snapshots.add(snapshot);
      }
    }

    final sanitized = TeammateStoreData(
      profiles: List.unmodifiable(profiles),
      records: List.unmodifiable(records),
      snapshots: List.unmodifiable(snapshots),
      lastAutoRefreshTrainingDate: lastAutoRefreshTrainingDate as String?,
    );
    return trimTeammateStoreData(sanitized, now: DateTime.now());
  }

  final List<TeammateProfile> profiles;
  final List<TeammateDailyRecord> records;
  final List<TeammateSolvedSnapshot> snapshots;
  final String? lastAutoRefreshTrainingDate;

  Map<String, dynamic> toJson() => {
        'profiles': profiles.map((profile) => profile.toJson()).toList(),
        'records': records.map((record) => record.toJson()).toList(),
        'snapshots': snapshots.map((snapshot) => snapshot.toJson()).toList(),
        'lastAutoRefreshTrainingDate': lastAutoRefreshTrainingDate,
      };
}

class TeammateRankEntry {
  const TeammateRankEntry({
    required this.profile,
    required this.record,
  });

  final TeammateProfile profile;
  final TeammateDailyRecord record;
}

class TeammateDailyRanking {
  const TeammateDailyRanking({
    required this.trainingDate,
    required this.entries,
  });

  final String trainingDate;
  final List<TeammateRankEntry> entries;
}

List<TeammateAccount> normalizeTeammateAccounts(
  Iterable<TeammateAccount> accounts,
) {
  final byPlatform = <String, TeammateAccount>{};
  for (final account in accounts) {
    final handle = account.handle.trim();
    if (!isSupportedOjId(account.platform) || handle.isEmpty) {
      continue;
    }
    byPlatform[account.platform] = account.copyWith(handle: handle);
  }
  return List.unmodifiable([
    for (final meta in supportedOjs)
      if (byPlatform.containsKey(meta.id)) byPlatform[meta.id]!,
  ]);
}

bool isSupportedOjId(String value) {
  return supportedOjs.any((meta) => meta.id == value);
}

String teammatePlatformName(String platform) {
  return supportedOjs.firstWhere((meta) => meta.id == platform).name;
}

String buildTeammateId(DateTime time) {
  final micros = time.microsecondsSinceEpoch.toRadixString(36);
  return 't$micros';
}

TeammateStoreData trimTeammateStoreData(
  TeammateStoreData data, {
  DateTime? now,
}) {
  final today = trainingDateFor(now ?? DateTime.now());
  final keepDates = recentTrainingDates(today);
  final keptProfiles = List<TeammateProfile>.unmodifiable(
    data.profiles.take(maxTeammates),
  );
  final teammateIds = keptProfiles.map((profile) => profile.id).toSet();
  final records = data.records
      .where((record) =>
          teammateIds.contains(record.teammateId) &&
          keepDates.contains(record.trainingDate))
      .toList()
    ..sort((a, b) {
      final byDate = b.trainingDate.compareTo(a.trainingDate);
      if (byDate != 0) {
        return byDate;
      }
      return a.teammateId.compareTo(b.teammateId);
    });
  final snapshots = data.snapshots
      .where((snapshot) =>
          teammateIds.contains(snapshot.teammateId) &&
          keepDates.contains(snapshot.trainingDate))
      .toList()
    ..sort((a, b) {
      final byDate = b.trainingDate.compareTo(a.trainingDate);
      if (byDate != 0) {
        return byDate;
      }
      final byTeammate = a.teammateId.compareTo(b.teammateId);
      if (byTeammate != 0) {
        return byTeammate;
      }
      return a.platform.compareTo(b.platform);
    });
  return TeammateStoreData(
    profiles: keptProfiles,
    records: List.unmodifiable(records),
    snapshots: List.unmodifiable(snapshots),
    lastAutoRefreshTrainingDate: data.lastAutoRefreshTrainingDate,
  );
}

List<String> recentTrainingDates(String trainingDate,
    {int days = teammateHistoryDays}) {
  final parsed = DateTime.parse(trainingDate);
  return List.unmodifiable([
    for (var offset = 0; offset < days; offset++)
      dateKey(parsed.subtract(Duration(days: offset))),
  ]);
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
