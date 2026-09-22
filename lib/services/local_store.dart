import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_config.dart';
import '../models/contest_record.dart';
import '../models/problem_record.dart';
import '../models/refresh_log_entry.dart';
import '../models/solved_snapshot.dart';
import '../models/teammate.dart';
import '../models/training.dart';

const maxStoredSnapshots = 6000;

class CoreStoreSnapshot {
  const CoreStoreSnapshot({
    required this.problems,
    required this.training,
    required this.contests,
  });

  final List<ProblemRecord> problems;
  final TrainingStoreData training;
  final List<ContestRecord> contests;
}

List<SolvedSnapshot> retainRecentSnapshots(
  Iterable<SolvedSnapshot> snapshots,
) {
  final items = snapshots.toList();
  if (items.length <= maxStoredSnapshots) {
    return List.unmodifiable(items);
  }
  items.sort((a, b) => a.fetchedAt.compareTo(b.fetchedAt));
  return List.unmodifiable(
    items.sublist(items.length - maxStoredSnapshots),
  );
}

class LocalStore {
  LocalStore({Directory? supportDirectory})
      : _supportDirectory = supportDirectory;

  static const _configKey = 'app_config_v1';
  static const _snapshotsFile = 'snapshots_v1.json';
  static const _problemsFile = 'problems_v1.json';
  static const _contestsFile = 'contests_v1.json';
  static const _teammatesFile = 'teammates_v1.json';
  static const _trainingFile = 'training_v1.json';
  static const _problemTrainingTransactionFile =
      'problem_training_transaction_v1.json';
  static const _refreshLogsFile = 'refresh_logs_v1.json';
  static const _maxRefreshLogs = 200;

  final Directory? _supportDirectory;
  Future<void> _problemTrainingTransactionTail = Future.value();
  Future<void> _coreWriteTail = Future.value();

  Future<Directory> supportDirectory() async {
    return _supportDirectory ?? await getApplicationSupportDirectory();
  }

  Future<AppConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_configKey);
    if (raw == null) {
      return AppConfig.defaults();
    }
    try {
      final data = jsonDecode(raw);
      if (data is! Map) {
        debugPrint('应用配置 JSON 无效：应为对象。');
        return AppConfig.defaults();
      }
      final json = Map<String, dynamic>.from(data);
      final config = AppConfig.fromJson(json);
      if (json['configVersion'] != currentAppConfigVersion) {
        await prefs.setString(_configKey, jsonEncode(config.toJson()));
      }
      return config;
    } catch (_) {
      debugPrint('解析应用配置失败，已使用默认值。');
      return AppConfig.defaults();
    }
  }

  Future<void> saveConfig(AppConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, jsonEncode(config.toJson()));
  }

  Future<List<SolvedSnapshot>> loadSnapshots() async {
    final file = await _snapshotFile();
    if (!await _hasStoredFile(file)) {
      return [];
    }
    try {
      final data = await _readJsonWithBackup(file);
      if (data is! List) {
        debugPrint('快照 JSON 无效：应为列表。');
        return [];
      }
      final snapshots = <SolvedSnapshot>[];
      for (final item in data) {
        try {
          if (item is! Map) {
            debugPrint('已跳过无效快照：应为对象。');
            continue;
          }
          final snapshot = SolvedSnapshot.tryFromJson(
            Map<String, dynamic>.from(item),
          );
          if (snapshot == null) {
            debugPrint('已跳过无效快照条目。');
            continue;
          }
          snapshots.add(snapshot);
        } catch (_) {
          debugPrint('已跳过无效快照条目。');
          continue;
        }
      }
      final kept = retainRecentSnapshots(snapshots);
      if (kept.length != snapshots.length) {
        await _writeJsonAtomically(
          file,
          kept.map((item) => item.toJson()).toList(),
        );
      }
      return kept;
    } catch (_) {
      debugPrint('解析快照失败，已使用空列表。');
      return [];
    }
  }

  Future<void> saveSnapshots(List<SolvedSnapshot> snapshots) async {
    final file = await _snapshotFile();
    await file.parent.create(recursive: true);
    final kept = retainRecentSnapshots(snapshots);
    await _writeJsonAtomically(
      file,
      kept.map((item) => item.toJson()).toList(),
    );
  }

  Future<void> replaceSnapshots(List<SolvedSnapshot> snapshots) async {
    final file = await _snapshotFile();
    await file.parent.create(recursive: true);
    final kept = retainRecentSnapshots(snapshots);
    await _writeJsonAtomically(
      file,
      kept.map((item) => item.toJson()).toList(),
    );
  }

  Future<List<RefreshLogEntry>> loadRefreshLogs() async {
    final file = await _refreshLogsFileHandle();
    if (!await _hasStoredFile(file)) {
      return [];
    }
    try {
      final data = await _readJsonWithBackup(file);
      if (data is! List) {
        debugPrint('刷新日志 JSON 无效：应为列表。');
        return [];
      }
      final entries = <RefreshLogEntry>[];
      for (final item in data) {
        try {
          if (item is! Map) {
            debugPrint('已跳过无效刷新日志：应为对象。');
            continue;
          }
          final entry = RefreshLogEntry.tryFromJson(
            Map<String, dynamic>.from(item),
          );
          if (entry == null) {
            debugPrint('已跳过无效刷新日志条目。');
            continue;
          }
          entries.add(entry);
        } catch (_) {
          debugPrint('已跳过无效刷新日志条目。');
        }
      }
      entries.sort((a, b) => b.fetchedAt.compareTo(a.fetchedAt));
      return List.unmodifiable(entries.take(_maxRefreshLogs).toList());
    } catch (_) {
      debugPrint('解析刷新日志失败，已使用空列表。');
      return [];
    }
  }

  Future<void> saveRefreshLogs(List<RefreshLogEntry> entries) async {
    final file = await _refreshLogsFileHandle();
    await file.parent.create(recursive: true);
    final sorted = [...entries]
      ..sort((a, b) => b.fetchedAt.compareTo(a.fetchedAt));
    final kept = sorted.take(_maxRefreshLogs).toList();
    await _writeJsonAtomically(
      file,
      kept.map((item) => item.toJson()).toList(),
    );
  }

  Future<List<ProblemRecord>> loadProblems() async {
    final file = await _problemsFileHandle();
    if (!await _hasStoredFile(file)) {
      return [];
    }
    try {
      final data = await _readJsonWithBackup(file);
      if (data is! List) {
        debugPrint('题单 JSON 无效：应为列表。');
        return [];
      }
      final problems = <ProblemRecord>[];
      for (final item in data) {
        try {
          if (item is! Map) {
            debugPrint('已跳过无效题目：应为对象。');
            continue;
          }
          final problem = ProblemRecord.tryFromJson(
            Map<String, dynamic>.from(item),
          );
          if (problem == null) {
            debugPrint('已跳过无效题目条目。');
            continue;
          }
          problems.add(problem);
        } catch (_) {
          debugPrint('已跳过无效题目条目。');
        }
      }
      problems.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return List.unmodifiable(problems);
    } catch (_) {
      debugPrint('解析题单失败，已使用空列表。');
      return [];
    }
  }

  Future<void> saveProblems(List<ProblemRecord> problems) async {
    await _enqueueCoreWrite(() => _writeProblems(problems));
  }

  Future<void> replaceProblems(List<ProblemRecord> problems) =>
      saveProblems(problems);

  Future<List<ContestRecord>> loadContests() async {
    final file = await _contestsFileHandle();
    if (!await _hasStoredFile(file)) {
      return [];
    }
    try {
      final data = await _readJsonWithBackup(file);
      if (data is! List) {
        debugPrint('比赛记录 JSON 无效：应为列表。');
        return [];
      }
      final contests = <ContestRecord>[];
      for (final item in data) {
        try {
          if (item is! Map) {
            debugPrint('已跳过无效比赛记录：应为对象。');
            continue;
          }
          final contest = ContestRecord.tryFromJson(
            Map<String, dynamic>.from(item),
          );
          if (contest == null) {
            debugPrint('已跳过无效比赛记录条目。');
            continue;
          }
          contests.add(contest);
        } catch (_) {
          debugPrint('已跳过无效比赛记录条目。');
        }
      }
      contests.sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        if (byDate != 0) {
          return byDate;
        }
        return b.updatedAt.compareTo(a.updatedAt);
      });
      return List.unmodifiable(contests);
    } catch (_) {
      debugPrint('解析比赛记录失败，已使用空列表。');
      return [];
    }
  }

  Future<void> saveContests(List<ContestRecord> contests) async {
    await _enqueueCoreWrite(() => _writeContests(contests));
  }

  Future<void> replaceContests(List<ContestRecord> contests) =>
      saveContests(contests);

  Future<TeammateStoreData> loadTeammates() async {
    final file = await _teammatesFileHandle();
    if (!await _hasStoredFile(file)) {
      return const TeammateStoreData();
    }
    try {
      final data = await _readJsonWithBackup(file);
      if (data is! Map) {
        debugPrint('队友数据 JSON 无效：应为对象。');
        return const TeammateStoreData();
      }
      return TeammateStoreData.tryFromJson(Map<String, dynamic>.from(data)) ??
          const TeammateStoreData();
    } catch (_) {
      debugPrint('解析队友数据失败，已使用空列表。');
      return const TeammateStoreData();
    }
  }

  Future<void> saveTeammates(TeammateStoreData teammates) async {
    final file = await _teammatesFileHandle();
    await file.parent.create(recursive: true);
    await _writeJsonAtomically(
      file,
      trimTeammateStoreData(teammates).toJson(),
    );
  }

  Future<void> replaceTeammates(TeammateStoreData teammates) async {
    final file = await _teammatesFileHandle();
    await file.parent.create(recursive: true);
    await _writeJsonAtomically(file, teammates.toJson());
  }

  Future<TrainingStoreData> loadTraining() async {
    final file = await _trainingFileHandle();
    if (!await _hasStoredFile(file)) {
      return const TrainingStoreData();
    }
    try {
      final data = await _readJsonWithBackup(file);
      if (data is! Map) {
        debugPrint('训练数据 JSON 无效：应为对象。');
        return const TrainingStoreData();
      }
      return TrainingStoreData.tryFromJson(Map<String, dynamic>.from(data)) ??
          const TrainingStoreData();
    } catch (_) {
      debugPrint('解析训练数据失败，已使用空数据。');
      return const TrainingStoreData();
    }
  }

  Future<void> saveTraining(TrainingStoreData training) async {
    await _enqueueCoreWrite(() => _writeTraining(training));
  }

  Future<void> replaceTraining(TrainingStoreData training) =>
      saveTraining(training);

  Future<void> recoverPendingProblemTrainingTransaction() {
    return _enqueueCoreWrite(
      () => _enqueueProblemTrainingTransaction(
        _recoverPendingProblemTrainingTransaction,
      ),
    );
  }

  Future<void> saveProblemsAndTraining(
    List<ProblemRecord> problems,
    TrainingStoreData training,
  ) {
    return _enqueueCoreWrite(
      () => _enqueueProblemTrainingTransaction(
        () => _commitCoreTransaction(problems, training),
      ),
    );
  }

  Future<void> replaceCoreData(
    List<ProblemRecord> problems,
    TrainingStoreData training,
    List<ContestRecord> contests,
  ) {
    return _enqueueCoreWrite(
      () => _enqueueProblemTrainingTransaction(
        () => _commitCoreTransaction(
          problems,
          training,
          contests: contests,
        ),
      ),
    );
  }

  Future<void> waitForCoreWrites() => _coreWriteTail;

  Future<CoreStoreSnapshot> loadCoreBackupSnapshot() {
    return _enqueueCoreWrite(() async {
      return CoreStoreSnapshot(
        problems: await _loadCoreProblemsStrict(),
        training: await _loadCoreTrainingStrict(),
        contests: await _loadCoreContestsStrict(),
      );
    });
  }

  Future<List<ProblemRecord>> _loadCoreProblemsStrict() async {
    final file = await _problemsFileHandle();
    if (!await _hasStoredFile(file)) {
      return const [];
    }
    final problems = await _readParsedJsonWithBackup(
      file,
      _parseTransactionProblems,
    );
    final sorted = [...problems]
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return List.unmodifiable(sorted);
  }

  Future<TrainingStoreData> _loadCoreTrainingStrict() async {
    final file = await _trainingFileHandle();
    if (!await _hasStoredFile(file)) {
      return const TrainingStoreData();
    }
    return _readParsedJsonWithBackup(file, _parseCoreTrainingDataStrict);
  }

  Future<List<ContestRecord>> _loadCoreContestsStrict() async {
    final file = await _contestsFileHandle();
    if (!await _hasStoredFile(file)) {
      return const [];
    }
    final contests = await _readParsedJsonWithBackup(
      file,
      _parseCoreContestsStrict,
    );
    final sorted = [...contests]..sort((left, right) {
        final byDate = right.date.compareTo(left.date);
        return byDate != 0 ? byDate : right.updatedAt.compareTo(left.updatedAt);
      });
    return List.unmodifiable(sorted);
  }

  Future<void> _recoverPendingProblemTrainingTransaction() async {
    final transaction = await _problemTrainingTransactionFileHandle();
    if (!await _hasStoredFile(transaction)) {
      return;
    }
    final decoded = await _readJsonWithBackup(transaction);
    if (decoded is! Map) {
      throw const FormatException('Problem/training transaction is invalid.');
    }
    final json = Map<String, dynamic>.from(decoded);
    final schemaVersion = json['schemaVersion'];
    if (schemaVersion != 1 && schemaVersion != 2) {
      throw const FormatException(
        'Problem/training transaction version is unsupported.',
      );
    }
    final problems = _parseTransactionProblems(json['problems']);
    final rawTraining = json['training'];
    if (rawTraining is! Map) {
      throw const FormatException('Transaction training data is invalid.');
    }
    final training = TrainingStoreData.tryFromJson(
      Map<String, dynamic>.from(rawTraining),
    );
    if (training == null) {
      throw const FormatException('Transaction training data is invalid.');
    }
    final contests =
        schemaVersion == 2 ? _parseCoreContestsStrict(json['contests']) : null;
    await _writeProblems(problems);
    await _writeTraining(training);
    if (contests != null) {
      await _writeContests(contests);
    }
    await _clearProblemTrainingTransaction(transaction);
  }

  Future<void> _commitCoreTransaction(
    List<ProblemRecord> problems,
    TrainingStoreData training, {
    List<ContestRecord>? contests,
  }) async {
    await _recoverPendingProblemTrainingTransaction();
    final transaction = await _problemTrainingTransactionFileHandle();
    await _writeJsonAtomically(transaction, {
      'schemaVersion': contests == null ? 1 : 2,
      'problems': problems.map((item) => item.toStorageJson()).toList(),
      'training': training.toJson(),
      if (contests != null)
        'contests': contests.map((item) => item.toStorageJson()).toList(),
    });
    try {
      await _writeProblems(problems);
      await _writeTraining(training);
      if (contests != null) {
        await _writeContests(contests);
      }
    } catch (error, stackTrace) {
      try {
        await _recoverPendingProblemTrainingTransaction();
      } catch (_) {
        Error.throwWithStackTrace(error, stackTrace);
      }
    }
    await _clearProblemTrainingTransaction(transaction);
  }

  Future<void> _writeProblems(List<ProblemRecord> problems) async {
    final file = await _problemsFileHandle();
    await _writeJsonAtomically(
      file,
      problems.map((item) => item.toStorageJson()).toList(),
    );
  }

  Future<void> _writeTraining(TrainingStoreData training) async {
    final file = await _trainingFileHandle();
    await _writeJsonAtomically(file, training.toJson());
  }

  Future<void> _writeContests(List<ContestRecord> contests) async {
    final file = await _contestsFileHandle();
    await _writeJsonAtomically(
      file,
      contests.map((item) => item.toStorageJson()).toList(),
    );
  }

  Future<void> _clearProblemTrainingTransaction(File transaction) async {
    for (final file in [
      transaction,
      File('${transaction.path}.bak'),
      File('${transaction.path}.tmp'),
    ]) {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> _enqueueProblemTrainingTransaction(
    Future<void> Function() operation,
  ) {
    final next = _problemTrainingTransactionTail.then((_) => operation());
    _problemTrainingTransactionTail = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return next;
  }

  Future<T> _enqueueCoreWrite<T>(Future<T> Function() operation) {
    final next = _coreWriteTail.then((_) => operation());
    _coreWriteTail = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return next;
  }

  Future<File> _snapshotFile() async {
    final directory =
        _supportDirectory ?? await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}$_snapshotsFile');
  }

  Future<File> _problemsFileHandle() async {
    final directory =
        _supportDirectory ?? await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}$_problemsFile');
  }

  Future<File> _contestsFileHandle() async {
    final directory =
        _supportDirectory ?? await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}$_contestsFile');
  }

  Future<File> _teammatesFileHandle() async {
    final directory =
        _supportDirectory ?? await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}$_teammatesFile');
  }

  Future<File> _refreshLogsFileHandle() async {
    final directory =
        _supportDirectory ?? await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}$_refreshLogsFile');
  }

  Future<File> _trainingFileHandle() async {
    final directory =
        _supportDirectory ?? await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}$_trainingFile');
  }

  Future<File> _problemTrainingTransactionFileHandle() async {
    final directory =
        _supportDirectory ?? await getApplicationSupportDirectory();
    return File(
      '${directory.path}${Platform.pathSeparator}'
      '$_problemTrainingTransactionFile',
    );
  }
}

List<ProblemRecord> _parseTransactionProblems(Object? value) {
  if (value is! List) {
    throw const FormatException('Transaction problem data is invalid.');
  }
  final problems = <ProblemRecord>[];
  for (final item in value) {
    if (item is! Map) {
      throw const FormatException('Transaction problem data is invalid.');
    }
    final problem = ProblemRecord.tryFromJson(Map<String, dynamic>.from(item));
    if (problem == null) {
      throw const FormatException('Transaction problem data is invalid.');
    }
    problems.add(problem);
  }
  return List.unmodifiable(problems);
}

TrainingStoreData _parseCoreTrainingDataStrict(Object? value) {
  if (value is! Map) {
    throw const FormatException('Stored training data is invalid.');
  }
  final json = Map<String, dynamic>.from(value);
  final rawAttempts = json['attempts'];
  final rawLists = json['lists'];
  final rawTasks = json['tasks'];
  if (rawAttempts is! List || rawLists is! List || rawTasks is! List) {
    throw const FormatException('Stored training collections are invalid.');
  }
  final training = TrainingStoreData.tryFromJson(json);
  if (training == null ||
      training.attempts.length != rawAttempts.length ||
      training.lists.length != rawLists.length ||
      training.tasks.length != rawTasks.length ||
      (json['activeAttempt'] != null && training.activeAttempt == null)) {
    throw const FormatException('Stored training entry is invalid.');
  }
  return training;
}

List<ContestRecord> _parseCoreContestsStrict(Object? value) {
  if (value is! List) {
    throw const FormatException('Stored contest data is invalid.');
  }
  final contests = <ContestRecord>[];
  for (final item in value) {
    if (item is! Map) {
      throw const FormatException('Stored contest entry is invalid.');
    }
    final contest = ContestRecord.tryFromJson(
      Map<String, dynamic>.from(item),
    );
    if (contest == null) {
      throw const FormatException('Stored contest entry is invalid.');
    }
    contests.add(contest);
  }
  return List.unmodifiable(contests);
}

Future<T> _readParsedJsonWithBackup<T>(
  File file,
  T Function(Object? value) parse,
) async {
  Object? primaryError;
  for (final candidate in [file, File('${file.path}.bak')]) {
    if (!await candidate.exists()) {
      continue;
    }
    try {
      final text = await candidate.readAsString();
      final parsed = parse(jsonDecode(text));
      if (candidate.path != file.path) {
        await _writeTextAtomically(file, text, rotateBackup: false);
      }
      return parsed;
    } catch (error) {
      primaryError ??= error;
    }
  }
  throw primaryError ?? const FormatException('Stored JSON is unavailable.');
}

Future<bool> _hasStoredFile(File file) async {
  return await file.exists() || await File('${file.path}.bak').exists();
}

Future<dynamic> _readJsonWithBackup(File file) async {
  Object? primaryError;
  for (final candidate in [file, File('${file.path}.bak')]) {
    if (!await candidate.exists()) {
      continue;
    }
    try {
      final text = await candidate.readAsString();
      final decoded = jsonDecode(text);
      if (candidate.path != file.path) {
        await _writeTextAtomically(file, text, rotateBackup: false);
      }
      return decoded;
    } catch (error) {
      primaryError ??= error;
    }
  }
  throw primaryError ?? const FormatException('Stored JSON is unavailable.');
}

Future<void> _writeJsonAtomically(File file, Object? value) {
  return _writeTextAtomically(
    file,
    const JsonEncoder.withIndent('  ').convert(value),
  );
}

Future<void> _writeTextAtomically(
  File file,
  String contents, {
  bool rotateBackup = true,
}) async {
  await file.parent.create(recursive: true);
  final temporary = File('${file.path}.tmp');
  final backup = File('${file.path}.bak');
  if (await temporary.exists()) {
    await temporary.delete();
  }
  await temporary.writeAsString(contents, flush: true);
  var rotated = false;
  try {
    if (rotateBackup && await file.exists()) {
      if (await backup.exists()) {
        await backup.delete();
      }
      await file.rename(backup.path);
      rotated = true;
    } else if (await file.exists()) {
      await file.delete();
    }
    await temporary.rename(file.path);
  } catch (_) {
    if (await temporary.exists()) {
      await temporary.delete();
    }
    if (rotated && !await file.exists() && await backup.exists()) {
      await backup.rename(file.path);
    }
    rethrow;
  }
}
