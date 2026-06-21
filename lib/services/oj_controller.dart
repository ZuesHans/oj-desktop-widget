import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/errors.dart';
import '../core/solved_totals.dart';
import '../core/time.dart';
import '../models/app_config.dart';
import '../models/contest_record.dart';
import '../models/oj_state.dart';
import '../models/problem_record.dart';
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
    final problems = await storage.loadProblems();
    final contests = await storage.loadContests();
    final teammates = await storage.loadTeammates();
    state = state.copyWith(
      config: config,
      snapshots: snapshots,
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
      final snapshots = [
        ...state.snapshots,
        ...results.values
            .expand((items) => items)
            .map(SolvedSnapshot.fromResult),
      ];
      await storage.saveSnapshots(snapshots);
      state = state.copyWith(latest: results, snapshots: snapshots);
      _recomputeSummaries();
    } finally {
      refreshing = false;
      notifyListeners();
    }
  }

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
