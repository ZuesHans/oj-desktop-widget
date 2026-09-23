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
import '../models/training.dart';
import '../platform/startup_service.dart';
import 'backup_service.dart';
import 'automatic_backup_service.dart';
import 'browser_import_service.dart';
import 'contest_record_service.dart';
import 'daily_summary_service.dart';
import 'local_store.dart';
import 'problem_book_service.dart';
import 'refresh_service.dart';
import 'sync_secret_store.dart';
import 'sync_service.dart';
import 'teammate_service.dart';
import 'training_service.dart';

class OjController extends ChangeNotifier {
  OjController({
    required this.storage,
    required this.service,
    required this.startupService,
    ProblemBookService? problemBookService,
    ContestRecordService? contestRecordService,
    TeammateService? teammateService,
    SyncService? syncService,
    SyncSecretStore? syncSecretStore,
    TrainingService? trainingService,
    AutomaticBackupService? automaticBackupService,
    this.problemRefreshInterval = Duration.zero,
  })  : problemBookService =
            problemBookService ?? ProblemBookService(client: http.Client()),
        contestRecordService =
            contestRecordService ?? const ContestRecordService(),
        teammateService = teammateService ??
            TeammateService(
                client: http.Client(), providers: service.providers),
        syncService = syncService ?? SyncService(client: http.Client()),
        syncSecretStore = syncSecretStore ?? SecureSyncSecretStore(),
        trainingService = trainingService ?? const TrainingService(),
        automaticBackupService = automaticBackupService ??
            AutomaticBackupService(
              defaultDirectoryProvider: () async {
                final support = await storage.supportDirectory();
                return Directory(
                  '${support.path}${Platform.pathSeparator}backups',
                );
              },
            );

  final LocalStore storage;
  final RefreshService service;
  final StartupService startupService;
  final ProblemBookService problemBookService;
  final ContestRecordService contestRecordService;
  final TeammateService teammateService;
  final SyncService syncService;
  final SyncSecretStore syncSecretStore;
  final TrainingService trainingService;
  final AutomaticBackupService automaticBackupService;
  final Duration problemRefreshInterval;
  OjState state = OjState.initial();
  bool refreshing = false;
  bool refreshingTeammates = false;
  bool syncing = false;
  SyncResult? lastSyncResult;
  Timer? _timer;
  Timer? _automaticBackupTimer;
  Timer? _problemRefreshTimer;
  int _knownProblemRevision = 0;
  Future<bool>? _problemRefreshFuture;
  AutomaticBackupOverview? automaticBackupOverview;
  AutomaticBackupResult? lastAutomaticBackupResult;
  String automaticBackupError = '';
  bool automaticBackupRunning = false;

  Future<void> init() async {
    await storage.recoverPendingProblemTrainingTransaction();
    var config = await storage.loadConfig();
    config = await _withResolvedAutomaticBackupDirectory(config);
    final snapshots = await storage.loadSnapshots();
    final refreshLogs = await storage.loadRefreshLogs();
    final coreSnapshot = await storage.loadCoreBackupSnapshot();
    final storedProblems = coreSnapshot.problems;
    var problems = storedProblems;
    final contests = coreSnapshot.contests;
    final teammates = await storage.loadTeammates();
    var training = coreSnapshot.training;
    training = trainingService.migrateLegacyAttempts(problems, training);
    problems = trainingService.normalizeLegacyProblems(problems);
    training = trainingService.normalizeTrainingData(training);
    final normalizedProblems = _changedProblems(storedProblems, problems);
    if (normalizedProblems.isNotEmpty) {
      await storage.saveProblems(normalizedProblems);
    }
    await storage.saveTraining(training);
    final problemSnapshot = await storage.loadProblemSnapshot();
    _knownProblemRevision = problemSnapshot.revision;
    state = state.copyWith(
      config: config,
      snapshots: snapshots,
      refreshLogs: refreshLogs,
      problems: problemSnapshot.problems,
      contests: contests,
      teammates: teammates,
      training: training,
    );
    try {
      await startupService.setEnabled(
        config.closeToTray && config.launchAtStartup,
      );
    } catch (error) {
      debugPrint('Failed to synchronize startup registration: $error');
    }
    _recomputeSummaries();
    _schedule();
    _scheduleProblemRefresh();
    await _configureAutomaticBackup(runIfDue: true);
    notifyListeners();
    await refresh();
    await maybeAutoRefreshTeammates();
  }

  Future<void> saveConfig(AppConfig config) async {
    var normalized =
        config.closeToTray ? config : config.copyWith(launchAtStartup: false);
    normalized = await _withResolvedAutomaticBackupDirectory(normalized);
    if (normalized.automaticBackup.enabled) {
      await automaticBackupService.validateDirectory(
        normalized.automaticBackup,
      );
    }
    await storage.saveConfig(normalized);
    state = state.copyWith(config: normalized);
    _schedule();
    await _configureAutomaticBackup(runIfDue: true);
    notifyListeners();
    Object? startupError;
    try {
      final startupUpdated =
          await startupService.setEnabled(normalized.launchAtStartup);
      if (!startupUpdated) {
        startupError = FetchException('登录时启动设置更新失败。');
      }
    } catch (error) {
      startupError = error;
    }
    if (startupError != null) {
      throw FetchException(normalizeError(startupError));
    }
  }

  Future<ImportResult> importPortableBackup(
    File backupFile, {
    Directory? safetyBackupDirectory,
  }) async {
    final backupText = await backupFile.readAsString();
    final coreBackup = isCoreTrainingBackupJson(backupText)
        ? parseCoreTrainingBackupJson(backupText)
        : null;
    final imported =
        coreBackup == null ? parsePortableBackupJson(backupText) : null;
    final previousConfig = state.config;
    final previousSnapshots = state.snapshots;
    final previousProblems = state.problems;
    final previousContests = state.contests;
    final previousTeammates = state.teammates;
    final previousTraining = state.training;
    final previousRefreshLogs = state.refreshLogs;
    final resolvedSafetyDirectory = safetyBackupDirectory ??
        await automaticBackupService.resolveDirectory(
          state.config.automaticBackup,
        );
    final safetyBackup = await exportOjData(
      config: state.config,
      snapshots: state.snapshots,
      problems: state.problems,
      contests: state.contests,
      teammates: state.teammates,
      training: state.training,
      directory: resolvedSafetyDirectory,
      prefix: 'oj_float_pre_import_backup',
      writeDailySummary: false,
    );
    try {
      final rawProblems = coreBackup?.problems ?? imported!.problems;
      var importedTraining = trainingService.migrateLegacyAttempts(
        rawProblems,
        coreBackup?.training ?? imported!.training,
      );
      final importedProblems =
          trainingService.normalizeLegacyProblems(rawProblems);
      importedTraining =
          trainingService.normalizeTrainingData(importedTraining);
      final importedConfig = coreBackup == null
          ? imported!.config.copyWith(
              automaticBackup: previousConfig.automaticBackup,
            )
          : previousConfig;
      await storage.saveConfig(importedConfig);
      await storage.replaceSnapshots(
        coreBackup == null ? imported!.snapshots : previousSnapshots,
      );
      await storage.replaceCoreData(
        importedProblems,
        importedTraining,
        coreBackup?.contests ?? imported!.contests,
      );
      await storage.replaceTeammates(
        coreBackup == null ? imported!.teammates : previousTeammates,
      );
      await storage.saveRefreshLogs(
        coreBackup == null ? const [] : previousRefreshLogs,
      );
    } catch (error) {
      try {
        await storage.saveConfig(previousConfig);
        await storage.replaceSnapshots(previousSnapshots);
        await storage.replaceCoreData(
          previousProblems,
          previousTraining,
          previousContests,
        );
        await storage.replaceTeammates(previousTeammates);
        await storage.saveRefreshLogs(previousRefreshLogs);
      } catch (rollbackError) {
        throw FetchException(
          '导入失败，回滚也失败：${normalizeError(rollbackError)}',
        );
      }
      throw FetchException(
        '导入失败，当前配置和快照已恢复：'
        '${normalizeError(error)}',
      );
    }
    final problemSnapshot = await storage.loadProblemSnapshot();
    _knownProblemRevision = problemSnapshot.revision;
    state = state.copyWith(
      config: await storage.loadConfig(),
      snapshots: await storage.loadSnapshots(),
      refreshLogs: coreBackup == null ? const [] : previousRefreshLogs,
      problems: problemSnapshot.problems,
      contests: await storage.loadContests(),
      teammates: await storage.loadTeammates(),
      training: await storage.loadTraining(),
      latest: const {},
    );
    _recomputeSummaries();
    _schedule();
    await _configureAutomaticBackup(runIfDue: false);
    notifyListeners();
    try {
      final startupSynced =
          await startupService.setEnabled(state.config.launchAtStartup);
      if (!startupSynced) {
        throw FetchException('登录时启动设置更新失败。');
      }
    } catch (_) {
      // Import restores local state even if the OS startup toggle cannot sync.
    }
    return ImportResult(
      safetyBackupFile: safetyBackup.backupFile,
      scope: coreBackup == null
          ? BackupImportScope.portable
          : BackupImportScope.coreTraining,
    );
  }

  Future<void> refresh({bool syncAfterRefresh = true}) async {
    if (refreshing) {
      return;
    }
    refreshing = true;
    notifyListeners();
    try {
      final results = await service.refresh(state.config);
      final guarded = _applyRefreshGuard(results, state.snapshots);
      final snapshots = retainRecentSnapshots([
        ...state.snapshots,
        ...guarded.results.values
            .expand((items) => items)
            .where((result) => result.status == FetchStatus.success)
            .map(SolvedSnapshot.fromResult),
      ]);
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
      if (syncAfterRefresh && state.config.sync.autoSyncAfterRefresh) {
        unawaited(_syncSilently());
      }
    } finally {
      refreshing = false;
      notifyListeners();
    }
  }

  Future<String> loadSyncToken() {
    return syncSecretStore.readToken();
  }

  Future<void> saveSyncToken(String token) {
    return syncSecretStore.saveToken(token);
  }

  Future<SyncResult> syncNow() async {
    if (syncing) {
      return lastSyncResult ??
          const SyncResult(
            status: SyncStatus.skipped,
            endpointLabel: '',
            message: '同步正在进行中。',
          );
    }
    syncing = true;
    notifyListeners();
    try {
      await refreshProblemsIfChanged();
      final websiteProblems = await syncService.fetchWebsiteProblems(
        config: state.config.sync,
      );
      await refreshProblemsIfChanged();
      var problems = state.problems;
      if (websiteProblems.isNotEmpty) {
        problems = problemBookService.mergeSyncedProblems(
          state.problems,
          websiteProblems,
        );
        if (!listEquals(problems, state.problems)) {
          await storage.saveProblems(
            _changedProblems(state.problems, problems),
          );
          await _reloadProblemsFromStorage();
          problems = state.problems;
          notifyListeners();
        }
      }
      final result = await syncService.sync(
        config: state.config.sync,
        token: await syncSecretStore.readToken(),
        snapshots: state.snapshots,
        problems: problems,
      );
      lastSyncResult = result;
      return result;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> _syncSilently() async {
    try {
      await syncNow();
    } catch (_) {
      // 同步是可选功能，不能影响本地刷新。
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

  Future<void> toggleProblemFavorite(String id) async {
    await refreshProblemsIfChanged();
    final problem = _problemById(id);
    if (problem != null) {
      await saveProblem(problem.copyWith(isFavorite: !problem.isFavorite));
    }
  }

  Future<void> toggleProblemPinned(String id) async {
    await refreshProblemsIfChanged();
    final problem = _problemById(id);
    if (problem != null) {
      await saveProblem(problem.copyWith(isPinned: !problem.isPinned));
    }
  }

  Future<void> markProblemOpened(String id) async {
    await refreshProblemsIfChanged();
    final problem = _problemById(id);
    if (problem != null) {
      await saveProblem(
        problem.copyWith(
          lastOpenedAt: DateTime.now(),
          updatedAt: problem.updatedAt,
        ),
      );
    }
  }

  Future<void> saveProblem(ProblemRecord problem) async {
    await refreshProblemsIfChanged();
    final problems = problemBookService.upsert(state.problems, problem);
    final saved = _persistedProblemFor(problems, problem);
    await storage.saveProblem(saved);
    await _reloadProblemsFromStorage();
    notifyListeners();
  }

  Future<BrowserProblemImportResult> importBrowserProblem(
    BrowserProblemImport input,
  ) async {
    final uri = normalizeProblemUri(input.url);
    final platform =
        parseProblemPlatform(input.platform) ?? detectProblemPlatform(uri);
    final extractedExternalId = extractProblemExternalId(uri, platform);
    final externalId =
        extractedExternalId.isNotEmpty ? extractedExternalId : input.externalId;
    final now = DateTime.now();
    final candidate = ProblemRecord.create(
      title: input.title.isEmpty
          ? fallbackProblemTitle(uri, platform)
          : input.title,
      url: uri.toString(),
      platform: platform,
      workflowStatus: ProblemWorkflowStatus.backlog,
      tags: input.tags,
      difficulty: input.difficulty,
      externalId: externalId,
      now: now,
    );
    ProblemRecord? existing;
    for (final problem in state.problems) {
      if (canonicalProblemKey(problem) == canonicalProblemKey(candidate)) {
        existing = problem;
        break;
      }
    }
    final saved = existing == null
        ? candidate
        : existing.copyWith(
            title: input.title.isEmpty ? existing.title : input.title,
            url: uri.toString(),
            platform: platform,
            tags: {...existing.tags, ...input.tags}.toList(),
            difficulty: input.difficulty.isEmpty
                ? existing.difficulty
                : input.difficulty,
            externalId: externalId.isEmpty ? existing.externalId : externalId,
            updatedAt: now,
          );
    await saveProblem(saved);
    return BrowserProblemImportResult(
      created: existing == null,
      problemId: saved.id,
    );
  }

  Future<void> deleteProblem(String id) async {
    await refreshProblemsIfChanged();
    final problem = _problemById(id);
    if (problem == null) {
      return;
    }
    await saveProblem(
      problem.copyWith(
          workflowStatus: ProblemWorkflowStatus.archived,
          archivedAt: DateTime.now(),
          clearNextReviewAt: true),
    );
  }

  Future<void> restoreProblem(String id) async {
    await refreshProblemsIfChanged();
    final problem = _problemById(id);
    if (problem == null) {
      return;
    }
    await saveProblem(
      problem.copyWith(
        workflowStatus: ProblemWorkflowStatus.backlog,
        clearArchivedAt: true,
      ),
    );
  }

  Future<void> permanentlyDeleteProblem(String id) async {
    await refreshProblemsIfChanged();
    if (_problemById(id) == null) {
      return;
    }
    final training =
        trainingService.removeProblemReferences(state.training, id);
    await storage.deleteProblemAndSaveTraining(id, training);
    await _reloadProblemsFromStorage();
    state = state.copyWith(training: training);
    notifyListeners();
  }

  Future<void> addProblemsToSchedule(
    Iterable<String> problemIds,
    String trainingDate,
  ) async {
    final training = trainingService.addTasks(
      state.training,
      problemIds,
      trainingDate: trainingDate,
    );
    await storage.saveTraining(training);
    state = state.copyWith(training: training);
    notifyListeners();
  }

  Future<void> moveTrainingTask(String taskId, String trainingDate) async {
    final training =
        trainingService.moveTask(state.training, taskId, trainingDate);
    await storage.saveTraining(training);
    state = state.copyWith(training: training);
    notifyListeners();
  }

  Future<void> removeTrainingTask(String taskId) async {
    final training = trainingService.removeTask(state.training, taskId);
    await storage.saveTraining(training);
    state = state.copyWith(training: training);
    notifyListeners();
  }

  Future<void> startTraining(
    String problemId, {
    TrainingAttemptOrigin origin = TrainingAttemptOrigin.manual,
    String? taskId,
  }) async {
    final training = trainingService.startAttempt(
      state.training,
      problemId,
      origin: origin,
      taskId: taskId,
    );
    await storage.saveTraining(training);
    state = state.copyWith(training: training);
    notifyListeners();
  }

  Future<void> pauseTraining() async {
    final training = trainingService.pauseAttempt(state.training);
    await storage.saveTraining(training);
    state = state.copyWith(training: training);
    notifyListeners();
  }

  Future<void> resumeTraining() async {
    final training = trainingService.resumeAttempt(state.training);
    await storage.saveTraining(training);
    state = state.copyWith(training: training);
    notifyListeners();
  }

  Future<void> cancelTraining() async {
    final training = trainingService.cancelAttempt(state.training);
    await storage.saveTraining(training);
    state = state.copyWith(training: training);
    notifyListeners();
  }

  Future<TrainingAttempt> finishTraining({
    required AttemptResult result,
    AssistanceLevel assistance = AssistanceLevel.none,
    List<MistakeCategory> mistakes = const [],
    String reflection = '',
    String? favoriteListId,
  }) async {
    await refreshProblemsIfChanged();
    final active = state.training.activeAttempt;
    if (active == null) {
      throw FetchException('没有进行中的训练。');
    }
    final problem = state.problems.firstWhere(
      (item) => item.id == active.problemId,
      orElse: () => throw FetchException('进行中的题目已不存在。'),
    );
    final finished = trainingService.finishAttempt(
      data: state.training,
      problem: problem,
      result: result,
      assistance: assistance,
      mistakes: mistakes,
      reflection: reflection,
    );
    final training = favoriteListId == null
        ? finished.data
        : trainingService.addProblemToList(
            finished.data,
            favoriteListId,
            problem.id,
          );
    await storage.saveProblemAndTraining(finished.problem, training);
    await _reloadProblemsFromStorage();
    state = state.copyWith(training: training);
    notifyListeners();
    return finished.attempt;
  }

  Future<void> saveTrainingList(TrainingList list) async {
    final training = trainingService.upsertList(state.training, list);
    await storage.saveTraining(training);
    state = state.copyWith(training: training);
    notifyListeners();
  }

  Future<void> deleteTrainingList(String id) async {
    final training = trainingService.removeList(state.training, id);
    await storage.saveTraining(training);
    state = state.copyWith(training: training);
    notifyListeners();
  }

  TrainingAnalytics trainingAnalytics() {
    return trainingService.analytics(state.training, state.problems);
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

  Map<String, DailyActivityValue> todayActivityByAccountFor(String ojId) =>
      state.todaySummary.accountActivities[ojId] ?? const {};

  ProblemRecord? _problemById(String id) {
    for (final problem in state.problems) {
      if (problem.id == id) {
        return problem;
      }
    }
    return null;
  }

  Future<bool> refreshProblemsIfChanged() {
    final running = _problemRefreshFuture;
    if (running != null) {
      return running;
    }
    final operation = _refreshProblemsIfChanged();
    _problemRefreshFuture = operation;
    return operation.whenComplete(() {
      if (identical(_problemRefreshFuture, operation)) {
        _problemRefreshFuture = null;
      }
    });
  }

  Future<bool> _refreshProblemsIfChanged() async {
    final revision = await storage.problemRevision();
    if (revision == _knownProblemRevision) {
      return false;
    }
    await _reloadProblemsFromStorage();
    notifyListeners();
    return true;
  }

  Future<void> _reloadProblemsFromStorage() async {
    final snapshot = await storage.loadProblemSnapshot();
    _knownProblemRevision = snapshot.revision;
    state = state.copyWith(problems: snapshot.problems);
  }

  ProblemRecord _persistedProblemFor(
    List<ProblemRecord> problems,
    ProblemRecord submitted,
  ) {
    for (final problem in problems) {
      if (problem.id == submitted.id) {
        return problem;
      }
    }
    final key = canonicalProblemKey(submitted);
    return problems.firstWhere(
      (problem) => canonicalProblemKey(problem) == key,
    );
  }

  void _recomputeSummaries() {
    final today = trainingDateFor(DateTime.now());
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

  void _scheduleProblemRefresh() {
    _problemRefreshTimer?.cancel();
    if (problemRefreshInterval <= Duration.zero) {
      _problemRefreshTimer = null;
      return;
    }
    _problemRefreshTimer = Timer.periodic(
      problemRefreshInterval,
      (_) => unawaited(_pollProblemChanges()),
    );
  }

  Future<void> _pollProblemChanges() async {
    try {
      await refreshProblemsIfChanged();
    } catch (error) {
      debugPrint('Failed to refresh external problem changes: $error');
    }
  }

  Future<AppConfig> _withResolvedAutomaticBackupDirectory(
    AppConfig config,
  ) async {
    if (config.automaticBackup.directoryPath.trim().isNotEmpty) {
      return config;
    }
    final directory =
        await automaticBackupService.resolveDirectory(config.automaticBackup);
    final resolved = config.copyWith(
      automaticBackup: config.automaticBackup.copyWith(
        directoryPath: directory.path,
      ),
    );
    await storage.saveConfig(resolved);
    return resolved;
  }

  Future<void> _configureAutomaticBackup({required bool runIfDue}) async {
    _automaticBackupTimer?.cancel();
    _automaticBackupTimer = null;
    final config = state.config.automaticBackup;
    try {
      automaticBackupOverview = await automaticBackupService.inspect(config);
      automaticBackupError = automaticBackupOverview!.invalidBackupCount > 0
          ? '检测到 ${automaticBackupOverview!.invalidBackupCount} 个损坏的自动备份文件，已保留原文件。'
          : '';
    } catch (error) {
      automaticBackupError = '无法检查自动备份目录：${normalizeError(error)}';
    }
    if (!config.enabled) {
      return;
    }

    final now = automaticBackupService.currentTime;
    final scheduledToday = DateTime(
      now.year,
      now.month,
      now.day,
      config.timeMinutes ~/ 60,
      config.timeMinutes % 60,
    );
    if (runIfDue && !now.isBefore(scheduledToday)) {
      await _runAutomaticBackup(notify: false);
    }
    _scheduleNextAutomaticBackup();
  }

  void _scheduleNextAutomaticBackup() {
    _automaticBackupTimer?.cancel();
    final config = state.config.automaticBackup;
    if (!config.enabled) {
      _automaticBackupTimer = null;
      return;
    }
    final now = automaticBackupService.currentTime;
    var next = DateTime(
      now.year,
      now.month,
      now.day,
      config.timeMinutes ~/ 60,
      config.timeMinutes % 60,
    );
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    _automaticBackupTimer = Timer(next.difference(now), () async {
      await _runAutomaticBackup();
      _scheduleNextAutomaticBackup();
    });
  }

  Future<void> _runAutomaticBackup({bool notify = true}) async {
    if (automaticBackupRunning || !state.config.automaticBackup.enabled) {
      return;
    }
    automaticBackupRunning = true;
    try {
      final snapshot = await storage.loadCoreBackupSnapshot();
      final result = await automaticBackupService.createBackup(
        config: state.config.automaticBackup,
        problems: snapshot.problems,
        training: snapshot.training,
        contests: snapshot.contests,
      );
      lastAutomaticBackupResult = result;
      automaticBackupOverview = await automaticBackupService.inspect(
        state.config.automaticBackup,
      );
      if (result.cleanupFailures.isNotEmpty) {
        automaticBackupError =
            '备份已完成，但 ${result.cleanupFailures.length} 个旧备份无法清理。';
      } else if (result.invalidBackupCount > 0) {
        automaticBackupError =
            '检测到 ${result.invalidBackupCount} 个损坏的自动备份文件，已保留原文件。';
      } else {
        automaticBackupError = '';
      }
    } catch (error) {
      automaticBackupError = '自动备份失败：${normalizeError(error)}';
    } finally {
      automaticBackupRunning = false;
      if (notify) {
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _automaticBackupTimer?.cancel();
    _problemRefreshTimer?.cancel();
    service.dispose();
    problemBookService.dispose();
    teammateService.dispose();
    syncService.dispose();
    super.dispose();
  }
}

List<ProblemRecord> _changedProblems(
  List<ProblemRecord> previous,
  List<ProblemRecord> next,
) {
  final previousById = {for (final problem in previous) problem.id: problem};
  return List.unmodifiable([
    for (final problem in next)
      if (previousById[problem.id] == null ||
          !mapEquals(
            previousById[problem.id]!.toStorageJson(),
            problem.toStorageJson(),
          ))
        problem,
  ]);
}

class _GuardedRefresh {
  const _GuardedRefresh({required this.results, required this.logs});

  final Map<String, List<FetchResult>> results;
  final List<RefreshLogEntry> logs;
}
