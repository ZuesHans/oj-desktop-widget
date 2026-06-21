import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/errors.dart';
import '../core/solved_totals.dart';
import '../core/time.dart';
import '../models/app_config.dart';
import '../models/contest_record.dart';
import '../models/fetch_result.dart';
import '../models/oj_state.dart';
import '../models/problem_record.dart';
import '../models/refresh_log_entry.dart';
import '../models/solved_snapshot.dart';
import '../models/teammate.dart';
import '../platform/startup_service.dart';
import 'backup_service.dart';
import 'contest_record_service.dart';
import 'daily_summary_service.dart';
import 'local_store.dart';
import 'problem_book_service.dart';
import 'refresh_service.dart';
import 'teammate_service.dart';

class OjController extends ChangeNotifier {
  OjController({
    required this.storage,
    required this.service,
    required this.startupService,
    ProblemBookService? problemBookService,
    ContestRecordService? contestRecordService,
    TeammateService? teammateService,
  })  : problemBookService =
            problemBookService ?? ProblemBookService(client: http.Client()),
        contestRecordService =
            contestRecordService ?? const ContestRecordService(),
        teammateService = teammateService ??
            TeammateService(
                client: http.Client(), providers: service.providers);

  final LocalStore storage;
  final RefreshService service;
  final StartupService startupService;
  final ProblemBookService problemBookService;
  final ContestRecordService contestRecordService;
  final TeammateService teammateService;
  OjState state = OjState.initial();
  bool refreshing = false;
  bool refreshingTeammates = false;
  Timer? _timer;

  Future<void> init() async {
    final config = await storage.loadConfig();
    final snapshots = await storage.loadSnapshots();
    final refreshLogs = await storage.loadRefreshLogs();
    final problems = await storage.loadProblems();
    final contests = await storage.loadContests();
    final teammates = await storage.loadTeammates();
    state = state.copyWith(
      config: config,
      snapshots: snapshots,
      refreshLogs: refreshLogs,
      problems: problems,
      contests: contests,
      teammates: teammates,
    );
    _recomputeSummaries();
    _schedule();
    notifyListeners();
    await refresh();
    await maybeAutoRefreshTeammates();
  }

  Future<void> saveConfig(AppConfig config) async {
    await storage.saveConfig(config);
    state = state.copyWith(config: config);
    _schedule();
    notifyListeners();
    Object? startupError;
    try {
      final startupUpdated =
          await startupService.setEnabled(config.launchAtStartup);
      if (!startupUpdated) {
        startupError = FetchException('Start at login update failed.');
      }
    } catch (error) {
      startupError = error;
    }
    await refresh();
    if (startupError != null) {
      throw FetchException(normalizeError(startupError));
    }
  }

  Future<ImportResult> importPortableBackup(
    File backupFile, {
    Directory? safetyBackupDirectory,
  }) async {
    final imported = parsePortableBackupJson(await backupFile.readAsString());
    final previousConfig = state.config;
    final previousSnapshots = state.snapshots;
    final previousProblems = state.problems;
    final previousContests = state.contests;
    final previousTeammates = state.teammates;
    final safetyBackup = await exportOjData(
      config: state.config,
      snapshots: state.snapshots,
      problems: state.problems,
      contests: state.contests,
      teammates: state.teammates,
      directory: safetyBackupDirectory,
      prefix: 'oj_float_pre_import_backup',
      writeDailySummary: false,
    );
    try {
      await storage.saveConfig(imported.config);
      await storage.replaceSnapshots(imported.snapshots);
      await storage.replaceProblems(imported.problems);
      await storage.replaceContests(imported.contests);
      await storage.replaceTeammates(imported.teammates);
    } catch (error) {
      try {
        await storage.saveConfig(previousConfig);
        await storage.replaceSnapshots(previousSnapshots);
        await storage.replaceProblems(previousProblems);
        await storage.replaceContests(previousContests);
        await storage.replaceTeammates(previousTeammates);
      } catch (rollbackError) {
        throw FetchException(
          'Import failed and rollback failed: ${normalizeError(rollbackError)}',
        );
      }
      throw FetchException(
        'Import failed. Current config and snapshots were restored: '
        '${normalizeError(error)}',
      );
    }
    state = state.copyWith(
      config: await storage.loadConfig(),
      snapshots: await storage.loadSnapshots(),
      refreshLogs: await storage.loadRefreshLogs(),
      problems: await storage.loadProblems(),
      contests: await storage.loadContests(),
      teammates: await storage.loadTeammates(),
      latest: const {},
    );
    _recomputeSummaries();
    _schedule();
    notifyListeners();
    try {
      final startupSynced =
          await startupService.setEnabled(state.config.launchAtStartup);
      if (!startupSynced) {
        throw FetchException('Start at login update failed.');
      }
    } catch (_) {
      // Import restores local state even if the OS startup toggle cannot sync.
    }
    return ImportResult(safetyBackupFile: safetyBackup.backupFile);
  }

  Future<void> refresh() async {
    if (refreshing) {
      return;
    }
    refreshing = true;
    notifyListeners();
    try {
      final results = await service.refresh(state.config);
      final guarded = _applyRefreshGuard(results, state.snapshots);
      final snapshots = [
        ...state.snapshots,
        ...guarded.results.values
            .expand((items) => items)
            .where((result) => result.status == FetchStatus.success)
            .map(SolvedSnapshot.fromResult),
      ];
      final refreshLogs = _trimRefreshLogs([
        ...guarded.logs,
        ...state.refreshLogs,
      ]);
      await storage.saveSnapshots(snapshots);
      await storage.saveRefreshLogs(refreshLogs);
      state = state.copyWith(
        latest: guarded.results,
        snapshots: snapshots,
        refreshLogs: refreshLogs,
      );
      _recomputeSummaries();
    } finally {
      refreshing = false;
      notifyListeners();
    }
  }

  _GuardedRefresh _applyRefreshGuard(
    Map<String, List<FetchResult>> results,
    List<SolvedSnapshot> snapshots,
  ) {
    final latestSuccess = _latestSuccessByAccount(snapshots);
    final guardedResults = <String, List<FetchResult>>{};
    final logs = <RefreshLogEntry>[];

    for (final entry in results.entries) {
      final guardedItems = <FetchResult>[];
      for (final result in entry.value) {
        final fetchedAt = result.fetchedAt ?? DateTime.now();
        final key = _accountKey(result.ojId, result.username);
        final previous = latestSuccess[key]?.solvedCount;
        if (result.status == FetchStatus.success &&
            result.solvedCount != null &&
            previous != null &&
            previous > 0 &&
            result.solvedCount! <= 0) {
          final message = '本次刷新返回 0，低于历史值 $previous，已保留旧数据。';
          final blocked = FetchResult.failure(
            ojId: result.ojId,
            username: result.username,
            error: message,
            fetchedAt: fetchedAt,
            source: result.source,
            solvedCount: result.solvedCount,
            previousSolvedCount: previous,
          );
          guardedItems.add(blocked);
          logs.add(_logFromResult(blocked, RefreshLogStatus.blocked, message));
          continue;
        }
        if (result.status == FetchStatus.success &&
            result.solvedCount != null &&
            previous != null &&
            result.solvedCount! < previous) {
          final message =
              '本次刷新结果 ${result.solvedCount} 低于历史值 $previous，已保留旧数据。';
          final blocked = FetchResult.failure(
            ojId: result.ojId,
            username: result.username,
            error: message,
            fetchedAt: fetchedAt,
            source: result.source,
            solvedCount: result.solvedCount,
            previousSolvedCount: previous,
          );
          guardedItems.add(blocked);
          logs.add(_logFromResult(blocked, RefreshLogStatus.blocked, message));
          continue;
        }

        final enriched = result.copyWith(previousSolvedCount: previous);
        guardedItems.add(enriched);
        final logStatus = enriched.status == FetchStatus.success
            ? _successLogStatus(enriched.source)
            : RefreshLogStatus.failure;
        logs.add(
          _logFromResult(
            enriched,
            logStatus,
            enriched.status == FetchStatus.success
                ? '刷新成功'
                : enriched.error ?? '刷新失败',
          ),
        );
      }
      guardedResults[entry.key] = List.unmodifiable(guardedItems);
    }

    return _GuardedRefresh(
      results: Map.unmodifiable(guardedResults),
      logs: List.unmodifiable(logs),
    );
  }

  Map<String, SolvedSnapshot> _latestSuccessByAccount(
    List<SolvedSnapshot> snapshots,
  ) {
    final latest = <String, SolvedSnapshot>{};
    for (final snapshot in snapshots) {
      if (snapshot.status != FetchStatus.success ||
          snapshot.solvedCount == null) {
        continue;
      }
      final key = _accountKey(snapshot.ojId, snapshot.username);
      final current = latest[key];
      if (current == null || snapshot.fetchedAt.isAfter(current.fetchedAt)) {
        latest[key] = snapshot;
      }
    }
    return latest;
  }

  RefreshLogStatus _successLogStatus(String source) {
    return source == 'unknown' ||
            source == 'primary' ||
            source == 'ojhunt' ||
            source == 'kenkoooo_ac_rank' ||
            source == 'leetcode_graphql' ||
            source == 'luogu_profile_html'
        ? RefreshLogStatus.success
        : RefreshLogStatus.fallbackSuccess;
  }

  RefreshLogEntry _logFromResult(
    FetchResult result,
    RefreshLogStatus status,
    String message,
  ) {
    return RefreshLogEntry.create(
      fetchedAt: result.fetchedAt ?? DateTime.now(),
      ojId: result.ojId,
      username: result.username,
      status: status,
      source: result.source,
      solvedCount: result.solvedCount,
      previousSolvedCount: result.previousSolvedCount,
      message: message,
    );
  }

  List<RefreshLogEntry> _trimRefreshLogs(List<RefreshLogEntry> logs) {
    final sorted = [...logs]
      ..sort((a, b) => b.fetchedAt.compareTo(a.fetchedAt));
    return List.unmodifiable(sorted.take(200).toList());
  }

  String _accountKey(String ojId, String username) => '$ojId\n$username';

  Future<void> maybeAutoRefreshTeammates() async {
    if (state.teammates.profiles.isEmpty ||
        !shouldAutoRefreshTeammates(
          DateTime.now(),
          state.teammates.lastAutoRefreshTrainingDate,
        )) {
      return;
    }
    await refreshAllTeammates(isAuto: true);
  }

  Future<ParsedProblemLink> parseProblemLink(String url) {
    return problemBookService.parseLink(url);
  }

  Future<void> saveProblem(ProblemRecord problem) async {
    final problems = problemBookService.upsert(state.problems, problem);
    await storage.saveProblems(problems);
    state = state.copyWith(problems: problems);
    notifyListeners();
  }

  Future<void> deleteProblem(String id) async {
    final problems = problemBookService.remove(state.problems, id);
    await storage.saveProblems(problems);
    state = state.copyWith(problems: problems);
    notifyListeners();
  }

  Future<void> markProblemAccepted(ProblemRecord problem) {
    return saveProblem(problem.copyWith(status: ProblemStatus.AC));
  }

  Future<void> saveContest(ContestRecord contest) async {
    final contests = contestRecordService.upsert(state.contests, contest);
    await storage.saveContests(contests);
    state = state.copyWith(contests: contests);
    notifyListeners();
  }

  Future<void> deleteContest(String id) async {
    final contests = contestRecordService.remove(state.contests, id);
    await storage.saveContests(contests);
    state = state.copyWith(contests: contests);
    notifyListeners();
  }

  List<ContestRankPoint> contestRankPoints() {
    return contestRecordService.buildRankPoints(state.contests);
  }

  Future<void> saveTeammate(TeammateProfile teammate) async {
    final exists =
        state.teammates.profiles.any((profile) => profile.id == teammate.id);
    final next = exists
        ? teammateService.updateTeammate(state.teammates, teammate)
        : teammateService.addTeammate(state.teammates, teammate);
    await storage.saveTeammates(next);
    state = state.copyWith(teammates: next);
    notifyListeners();
  }

  Future<void> deleteTeammate(String id) async {
    final next = teammateService.deleteTeammate(state.teammates, id);
    await storage.saveTeammates(next);
    state = state.copyWith(teammates: next);
    notifyListeners();
  }

  Future<void> refreshTeammate(String id) async {
    if (refreshingTeammates) {
      return;
    }
    refreshingTeammates = true;
    notifyListeners();
    try {
      final next = await teammateService.refreshTeammate(state.teammates, id);
      await storage.saveTeammates(next);
      state = state.copyWith(teammates: next);
    } finally {
      refreshingTeammates = false;
      notifyListeners();
    }
  }

  Future<void> refreshAllTeammates({bool isAuto = false}) async {
    if (refreshingTeammates) {
      return;
    }
    refreshingTeammates = true;
    notifyListeners();
    try {
      var next = await teammateService.refreshAll(state.teammates);
      if (isAuto) {
        next = teammateService.markAutoRefreshed(next);
      }
      await storage.saveTeammates(next);
      state = state.copyWith(teammates: next);
    } finally {
      refreshingTeammates = false;
      notifyListeners();
    }
  }

  List<TeammateRankEntry> teammateTodayRanking() {
    return teammateService.todayRanking(state.teammates);
  }

  List<TeammateDailyRanking> teammateRecentRankings() {
    return teammateService.recentDailyRankings(state.teammates);
  }

  int todayDeltaFor(String ojId) => state.todaySummary.deltas[ojId] ?? 0;

  Map<String, int> todayDeltaByAccountFor(String ojId) =>
      state.todaySummary.accountDeltas[ojId] ?? const {};

  void _recomputeSummaries() {
    final today = dateKey(DateTime.now());
    state = state.copyWith(
        todaySummary: DailySummary.fromSnapshots(today, state.snapshots));
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(minutes: state.config.refreshIntervalMinutes),
      (_) {
        unawaited(refresh());
        unawaited(maybeAutoRefreshTeammates());
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    service.dispose();
    problemBookService.dispose();
    teammateService.dispose();
    super.dispose();
  }
}

class _GuardedRefresh {
  const _GuardedRefresh({required this.results, required this.logs});

  final Map<String, List<FetchResult>> results;
  final List<RefreshLogEntry> logs;
}
