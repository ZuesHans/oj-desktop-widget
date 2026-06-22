import 'dart:async';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../core/errors.dart';
import '../core/solved_totals.dart';
import '../core/time.dart';
import '../models/teammate.dart';
import '../providers/oj_provider.dart';

class TeammateService {
  TeammateService({
    required this.client,
    required this.providers,
  });

  final http.Client client;
  final Map<String, OjProvider> providers;

  TeammateStoreData addTeammate(
    TeammateStoreData data,
    TeammateProfile profile, {
    DateTime? now,
  }) {
    if (data.profiles.length >= maxTeammates) {
      throw FetchException('最多添加 3 名队友');
    }
    if (data.profiles.any((item) => item.id == profile.id)) {
      throw FetchException('队友已存在');
    }
    final normalized = _validatedProfile(profile, now: now);
    return trimTeammateStoreData(
      TeammateStoreData(
        profiles: List.unmodifiable([...data.profiles, normalized]),
        records: data.records,
        snapshots: data.snapshots,
        lastAutoRefreshTrainingDate: data.lastAutoRefreshTrainingDate,
      ),
      now: now,
    );
  }

  TeammateStoreData updateTeammate(
    TeammateStoreData data,
    TeammateProfile profile, {
    DateTime? now,
  }) {
    final index = data.profiles.indexWhere((item) => item.id == profile.id);
    if (index < 0) {
      throw FetchException('队友不存在');
    }
    final previous = data.profiles[index];
    final normalized = _validatedProfile(profile, now: now);
    final changedPlatforms = _changedAccountPlatforms(previous, normalized);
    final profiles = [...data.profiles]..[index] = normalized;
    final records = changedPlatforms.isEmpty
        ? data.records
        : data.records.map((record) {
            if (record.teammateId != normalized.id) {
              return record;
            }
            final deltas = {
              for (final entry in record.perPlatformDelta.entries)
                if (!changedPlatforms.contains(entry.key))
                  entry.key: entry.value,
            };
            final errors = {
              for (final entry in record.errors.entries)
                if (!changedPlatforms.contains(entry.key))
                  entry.key: entry.value,
            };
            return TeammateDailyRecord(
              teammateId: record.teammateId,
              trainingDate: record.trainingDate,
              perPlatformDelta: Map.unmodifiable(deltas),
              totalDelta: deltas.values.fold<int>(0, (sum, item) => sum + item),
              refreshedAt: record.refreshedAt,
              errors: Map.unmodifiable(errors),
            );
          }).toList();
    return trimTeammateStoreData(
      TeammateStoreData(
        profiles: List.unmodifiable(profiles),
        records: List.unmodifiable(records),
        snapshots: List.unmodifiable(
          data.snapshots.where(
            (snapshot) =>
                snapshot.teammateId != normalized.id ||
                !changedPlatforms.contains(snapshot.platform),
          ),
        ),
        lastAutoRefreshTrainingDate: data.lastAutoRefreshTrainingDate,
      ),
      now: now,
    );
  }

  TeammateStoreData deleteTeammate(
    TeammateStoreData data,
    String teammateId, {
    DateTime? now,
  }) {
    return trimTeammateStoreData(
      TeammateStoreData(
        profiles: List.unmodifiable(
          data.profiles.where((profile) => profile.id != teammateId),
        ),
        records: List.unmodifiable(
          data.records.where((record) => record.teammateId != teammateId),
        ),
        snapshots: List.unmodifiable(
          data.snapshots.where((snapshot) => snapshot.teammateId != teammateId),
        ),
        lastAutoRefreshTrainingDate: data.lastAutoRefreshTrainingDate,
      ),
      now: now,
    );
  }

  Future<TeammateStoreData> refreshAll(
    TeammateStoreData data, {
    DateTime? now,
  }) async {
    var next = data;
    for (final profile in data.profiles) {
      next = await refreshTeammate(next, profile.id, now: now);
    }
    return trimTeammateStoreData(next, now: now);
  }

  Future<TeammateStoreData> refreshTeammate(
    TeammateStoreData data,
    String teammateId, {
    DateTime? now,
  }) async {
    final refreshTime = now ?? DateTime.now();
    final currentTrainingDate = trainingDateFor(refreshTime);
    final profile = data.profiles
        .where((item) => item.id == teammateId)
        .cast<TeammateProfile?>()
        .firstOrNull;
    if (profile == null) {
      throw FetchException('队友不存在');
    }

    final enabledAccounts =
        profile.accounts.where((account) => account.enabled).toList();
    if (enabledAccounts.isEmpty) {
      throw FetchException('至少启用一个平台账号');
    }
    final enabledPlatforms =
        enabledAccounts.map((account) => account.platform).toSet();
    final previousRecord = _recordFor(
      data.records,
      teammateId,
      currentTrainingDate,
    );
    final deltas = {
      for (final entry in previousRecord?.perPlatformDelta.entries ??
          const Iterable<MapEntry<String, int>>.empty())
        if (enabledPlatforms.contains(entry.key)) entry.key: entry.value,
    };
    final errors = {
      for (final entry in previousRecord?.errors.entries ??
          const Iterable<MapEntry<String, String>>.empty())
        if (enabledPlatforms.contains(entry.key)) entry.key: entry.value,
    };
    final snapshots = [...data.snapshots];

    final results = await Future.wait(
      enabledAccounts.map((account) => _refreshAccount(account)),
    );
    for (final result in results) {
      if (result.error != null) {
        errors[result.account.platform] = result.error!;
        continue;
      }
      final solvedTotal = result.solvedTotal!;
      errors.remove(result.account.platform);
      final snapshotIndex = snapshots.indexWhere(
        (snapshot) =>
            snapshot.teammateId == teammateId &&
            snapshot.platform == result.account.platform &&
            snapshot.trainingDate == currentTrainingDate,
      );
      final TeammateSolvedSnapshot snapshot;
      if (snapshotIndex < 0) {
        snapshot = TeammateSolvedSnapshot(
          teammateId: teammateId,
          platform: result.account.platform,
          trainingDate: currentTrainingDate,
          solvedTotalAtStart: solvedTotal,
          latestSolvedTotal: solvedTotal,
          updatedAt: refreshTime,
        );
        snapshots.add(snapshot);
      } else {
        final previous = snapshots[snapshotIndex];
        snapshot = previous.copyWith(
          latestSolvedTotal: solvedTotal,
          updatedAt: refreshTime,
        );
        snapshots[snapshotIndex] = snapshot;
      }
      deltas[result.account.platform] = math.max(
        0,
        snapshot.latestSolvedTotal - snapshot.solvedTotalAtStart,
      );
    }
    final totalDelta = deltas.values.fold<int>(0, (sum, item) => sum + item);

    final nextRecord = TeammateDailyRecord(
      teammateId: teammateId,
      trainingDate: currentTrainingDate,
      perPlatformDelta: Map.unmodifiable(deltas),
      totalDelta: totalDelta,
      refreshedAt: refreshTime,
      errors: Map.unmodifiable(errors),
    );
    final records = [
      for (final record in data.records)
        if (record.teammateId != teammateId ||
            record.trainingDate != currentTrainingDate)
          record,
      nextRecord,
    ];

    return trimTeammateStoreData(
      TeammateStoreData(
        profiles: data.profiles,
        records: List.unmodifiable(records),
        snapshots: List.unmodifiable(snapshots),
        lastAutoRefreshTrainingDate: data.lastAutoRefreshTrainingDate,
      ),
      now: refreshTime,
    );
  }

  TeammateStoreData markAutoRefreshed(
    TeammateStoreData data, {
    DateTime? now,
  }) {
    return TeammateStoreData(
      profiles: data.profiles,
      records: data.records,
      snapshots: data.snapshots,
      lastAutoRefreshTrainingDate: trainingDateFor(now ?? DateTime.now()),
    );
  }

  List<TeammateRankEntry> rankingForDate(
    TeammateStoreData data,
    String trainingDate,
  ) {
    final profilesById = {
      for (final profile in data.profiles) profile.id: profile,
    };
    final entries = [
      for (final record in data.records)
        if (record.trainingDate == trainingDate &&
            profilesById.containsKey(record.teammateId))
          TeammateRankEntry(
            profile: profilesById[record.teammateId]!,
            record: record,
          ),
    ];
    entries.sort(_compareRankEntries);
    return List.unmodifiable(entries);
  }

  List<TeammateRankEntry> todayRanking(
    TeammateStoreData data, {
    DateTime? now,
  }) {
    return rankingForDate(data, trainingDateFor(now ?? DateTime.now()));
  }

  List<TeammateDailyRanking> recentDailyRankings(
    TeammateStoreData data, {
    DateTime? now,
  }) {
    final dates = recentTrainingDates(trainingDateFor(now ?? DateTime.now()));
    return List.unmodifiable([
      for (final date in dates)
        TeammateDailyRanking(
          trainingDate: date,
          entries: rankingForDate(data, date),
        ),
    ]);
  }

  void dispose() => client.close();

  TeammateProfile _validatedProfile(
    TeammateProfile profile, {
    DateTime? now,
  }) {
    final nickname = profile.nickname.trim();
    if (nickname.isEmpty) {
      throw FetchException('昵称必填');
    }
    final accounts = normalizeTeammateAccounts(profile.accounts);
    if (!accounts.any((account) => account.enabled)) {
      throw FetchException('至少启用一个平台账号');
    }
    final timestamp = now ?? DateTime.now();
    return TeammateProfile(
      id: profile.id,
      nickname: nickname,
      accounts: accounts,
      createdAt: profile.createdAt,
      updatedAt: timestamp,
    );
  }

  Set<String> _changedAccountPlatforms(
    TeammateProfile previous,
    TeammateProfile next,
  ) {
    final previousByPlatform = {
      for (final account in previous.accounts) account.platform: account,
    };
    final nextByPlatform = {
      for (final account in next.accounts) account.platform: account,
    };
    return {
      for (final platform in {
        ...previousByPlatform.keys,
        ...nextByPlatform.keys
      })
        if (previousByPlatform[platform]?.handle !=
                nextByPlatform[platform]?.handle ||
            previousByPlatform[platform]?.enabled !=
                nextByPlatform[platform]?.enabled)
          platform,
    };
  }

  Future<_AccountRefreshResult> _refreshAccount(TeammateAccount account) async {
    final provider = providers[account.platform];
    if (provider == null) {
      return _AccountRefreshResult(
        account: account,
        error: '平台不可用',
      );
    }
    try {
      final profile = await provider
          .fetchProfile(client, account.handle)
          .timeout(const Duration(seconds: 18));
      return _AccountRefreshResult(
        account: account,
        solvedTotal: profile.solvedCount,
      );
    } catch (error) {
      return _AccountRefreshResult(
        account: account,
        error: normalizeError(error),
      );
    }
  }
}

class _AccountRefreshResult {
  const _AccountRefreshResult({
    required this.account,
    this.solvedTotal,
    this.error,
  });

  final TeammateAccount account;
  final int? solvedTotal;
  final String? error;
}

TeammateDailyRecord? _recordFor(
  List<TeammateDailyRecord> records,
  String teammateId,
  String trainingDate,
) {
  for (final record in records) {
    if (record.teammateId == teammateId &&
        record.trainingDate == trainingDate) {
      return record;
    }
  }
  return null;
}

int _compareRankEntries(TeammateRankEntry a, TeammateRankEntry b) {
  final byDelta = b.record.totalDelta.compareTo(a.record.totalDelta);
  if (byDelta != 0) {
    return byDelta;
  }
  return a.profile.nickname.compareTo(b.profile.nickname);
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
