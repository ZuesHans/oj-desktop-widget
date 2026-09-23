import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../core/time.dart';
import '../models/app_config.dart';
import '../models/contest_record.dart';
import '../models/problem_record.dart';
import '../models/training.dart';

const automaticBackupSchemaVersion = 3;
const automaticBackupScope = 'core_training';
const automaticBackupDailyKeepCount = 7;
const automaticBackupWeeklyKeepCount = 4;

enum AutomaticBackupOutcome { created, alreadyCreatedToday, unchanged }

class AutomaticBackupResult {
  const AutomaticBackupResult({
    required this.outcome,
    required this.directoryPath,
    required this.createdAt,
    required this.filePath,
    required this.contentHash,
    required this.invalidBackupCount,
    required this.cleanupFailures,
  });

  final AutomaticBackupOutcome outcome;
  final String directoryPath;
  final DateTime createdAt;
  final String? filePath;
  final String contentHash;
  final int invalidBackupCount;
  final List<String> cleanupFailures;
}

class AutomaticBackupOverview {
  const AutomaticBackupOverview({
    required this.directoryPath,
    required this.latestBackupAt,
    required this.latestBackupPath,
    required this.validBackupCount,
    required this.invalidBackupCount,
  });

  final String directoryPath;
  final DateTime? latestBackupAt;
  final String? latestBackupPath;
  final int validBackupCount;
  final int invalidBackupCount;
}

class CoreTrainingBackup {
  const CoreTrainingBackup({
    required this.createdAt,
    required this.backupType,
    required this.contentHash,
    required this.problems,
    required this.training,
    required this.contests,
  });

  final DateTime createdAt;
  final String backupType;
  final String contentHash;
  final List<ProblemRecord> problems;
  final TrainingStoreData training;
  final List<ContestRecord> contests;
}

class AutomaticBackupService {
  AutomaticBackupService({
    required Future<Directory> Function() defaultDirectoryProvider,
    DateTime Function()? now,
  })  : _defaultDirectoryProvider = defaultDirectoryProvider,
        _now = now ?? DateTime.now;

  final Future<Directory> Function() _defaultDirectoryProvider;
  final DateTime Function() _now;

  DateTime get currentTime => _now();

  Future<Directory> resolveDirectory(AutomaticBackupConfig config) async {
    final configured = config.directoryPath.trim();
    if (configured.isNotEmpty) {
      return Directory(configured).absolute;
    }
    return (await _defaultDirectoryProvider()).absolute;
  }

  Future<void> validateDirectory(AutomaticBackupConfig config) async {
    final directory = await resolveDirectory(config);
    await directory.create(recursive: true);
    final timestamp = _now().microsecondsSinceEpoch;
    final probe = File(
      '${directory.path}${Platform.pathSeparator}'
      '.oj_float_backup_write_test_$timestamp.tmp',
    );
    try {
      await probe.writeAsString('oj_float', flush: true);
      if (await probe.readAsString() != 'oj_float') {
        throw const FileSystemException('Backup directory write check failed.');
      }
    } finally {
      if (await probe.exists()) {
        await probe.delete();
      }
    }
  }

  Future<AutomaticBackupOverview> inspect(
    AutomaticBackupConfig config,
  ) async {
    final directory = await resolveDirectory(config);
    final scan = await _scan(directory);
    final latest = scan.valid.isEmpty ? null : scan.valid.first;
    return AutomaticBackupOverview(
      directoryPath: directory.path,
      latestBackupAt: latest?.backup.createdAt,
      latestBackupPath: latest?.file.path,
      validBackupCount: scan.valid.length,
      invalidBackupCount: scan.invalidCount,
    );
  }

  Future<AutomaticBackupResult> createBackup({
    required AutomaticBackupConfig config,
    required List<ProblemRecord> problems,
    required TrainingStoreData training,
    required List<ContestRecord> contests,
  }) async {
    final now = _now();
    final directory = await resolveDirectory(config);
    await directory.create(recursive: true);
    final scan = await _scan(directory);
    final data = _buildCoreData(
      problems: problems,
      training: training,
      contests: contests,
    );
    final contentHash = _contentHash(data);
    final today = dateKey(now);
    final todayBackup = scan.valid
        .where((entry) => dateKey(entry.backup.createdAt) == today)
        .firstOrNull;
    if (todayBackup != null) {
      return AutomaticBackupResult(
        outcome: AutomaticBackupOutcome.alreadyCreatedToday,
        directoryPath: directory.path,
        createdAt: todayBackup.backup.createdAt,
        filePath: todayBackup.file.path,
        contentHash: todayBackup.backup.contentHash,
        invalidBackupCount: scan.invalidCount,
        cleanupFailures: const [],
      );
    }
    final latest = scan.valid.firstOrNull;
    if (latest?.backup.contentHash == contentHash) {
      return AutomaticBackupResult(
        outcome: AutomaticBackupOutcome.unchanged,
        directoryPath: directory.path,
        createdAt: now,
        filePath: latest?.file.path,
        contentHash: contentHash,
        invalidBackupCount: scan.invalidCount,
        cleanupFailures: const [],
      );
    }

    final document = _buildBackupDocument(
      createdAt: now,
      backupType: 'automatic',
      contentHash: contentHash,
      data: data,
    );
    final target = await _availableBackupFile(directory, now);
    final temporary = File('${target.path}.tmp');
    try {
      await temporary.writeAsString(
        const JsonEncoder.withIndent('  ').convert(document),
        flush: true,
      );
      final verified = parseCoreTrainingBackupJson(
        await temporary.readAsString(),
      );
      if (verified.contentHash != contentHash) {
        throw const FormatException('Automatic backup verification failed.');
      }
      await temporary.rename(target.path);
    } catch (_) {
      if (await temporary.exists()) {
        await temporary.delete();
      }
      rethrow;
    }

    final completedScan = await _scan(directory);
    final cleanupFailures = await _rotate(completedScan.valid);
    return AutomaticBackupResult(
      outcome: AutomaticBackupOutcome.created,
      directoryPath: directory.path,
      createdAt: now,
      filePath: target.path,
      contentHash: contentHash,
      invalidBackupCount: completedScan.invalidCount,
      cleanupFailures: List.unmodifiable(cleanupFailures),
    );
  }

  Future<_BackupScan> _scan(Directory directory) async {
    if (!await directory.exists()) {
      return const _BackupScan(valid: [], invalidCount: 0);
    }
    final valid = <_StoredAutomaticBackup>[];
    var invalidCount = 0;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File || !_isAutomaticBackupFile(entity.path)) {
        continue;
      }
      try {
        final backup = parseCoreTrainingBackupJson(await entity.readAsString());
        if (backup.backupType != 'automatic') {
          invalidCount++;
          continue;
        }
        valid.add(_StoredAutomaticBackup(file: entity, backup: backup));
      } catch (_) {
        invalidCount++;
      }
    }
    valid.sort(
      (left, right) => right.backup.createdAt.compareTo(left.backup.createdAt),
    );
    return _BackupScan(
      valid: List.unmodifiable(valid),
      invalidCount: invalidCount,
    );
  }

  Future<List<String>> _rotate(
    List<_StoredAutomaticBackup> backups,
  ) async {
    final keep = <String>{};
    final dailyDates = <String>{};
    for (final backup in backups) {
      final day = dateKey(backup.backup.createdAt);
      if (dailyDates.length >= automaticBackupDailyKeepCount &&
          !dailyDates.contains(day)) {
        continue;
      }
      if (dailyDates.add(day)) {
        keep.add(backup.file.path);
      }
      if (dailyDates.length >= automaticBackupDailyKeepCount) {
        break;
      }
    }

    final representedWeeks = {
      for (final backup in backups.where(
        (entry) => keep.contains(entry.file.path),
      ))
        _weekStartKey(backup.backup.createdAt),
    };
    var weeklyKept = 0;
    for (final backup in backups.where(
      (entry) => !keep.contains(entry.file.path),
    )) {
      final week = _weekStartKey(backup.backup.createdAt);
      if (representedWeeks.add(week)) {
        keep.add(backup.file.path);
        weeklyKept++;
      }
      if (weeklyKept >= automaticBackupWeeklyKeepCount) {
        break;
      }
    }

    final failures = <String>[];
    for (final backup in backups) {
      if (keep.contains(backup.file.path)) {
        continue;
      }
      try {
        await backup.file.delete();
      } catch (_) {
        failures.add(backup.file.path);
      }
    }
    return failures;
  }
}

bool isCoreTrainingBackupJson(String text) {
  try {
    final decoded = jsonDecode(text);
    return decoded is Map &&
        decoded['schemaVersion'] == automaticBackupSchemaVersion &&
        decoded['app'] == 'oj_float' &&
        decoded['backupScope'] == automaticBackupScope;
  } catch (_) {
    return false;
  }
}

CoreTrainingBackup parseCoreTrainingBackupJson(String text) {
  final decoded = jsonDecode(text);
  if (decoded is! Map) {
    throw const FormatException('Backup JSON must be an object.');
  }
  final json = Map<String, dynamic>.from(decoded);
  if (json['schemaVersion'] != automaticBackupSchemaVersion ||
      json['app'] != 'oj_float' ||
      json['backupScope'] != automaticBackupScope) {
    throw const FormatException('Unsupported core backup format.');
  }
  final backupType = json['backupType'];
  if (backupType is! String || backupType.isEmpty) {
    throw const FormatException('Backup type is invalid.');
  }
  final createdAtRaw = json['createdAt'];
  final createdAt =
      createdAtRaw is String ? DateTime.tryParse(createdAtRaw) : null;
  if (createdAt == null) {
    throw const FormatException('Backup creation time is invalid.');
  }
  final rawData = json['data'];
  if (rawData is! Map) {
    throw const FormatException('Backup data is invalid.');
  }
  final data = Map<String, dynamic>.from(rawData);
  final storedHash = json['contentHash'];
  if (storedHash is! String || storedHash != _contentHash(data)) {
    throw const FormatException('Backup integrity check failed.');
  }

  final problems = _parseProblemsStrict(data['problems']);
  final training = _parseTrainingStrict(data['training']);
  final contests = _parseContestsStrict(data['contests']);
  _requireUnique(problems.map((item) => item.id), 'problem');
  _requireUnique(training.attempts.map((item) => item.id), 'attempt');
  _requireUnique(training.lists.map((item) => item.id), 'list');
  _requireUnique(training.tasks.map((item) => item.id), 'task');
  _requireUnique(contests.map((item) => item.id), 'contest');
  _validateCoreRelationships(problems, training);

  return CoreTrainingBackup(
    createdAt: createdAt,
    backupType: backupType,
    contentHash: storedHash,
    problems: List.unmodifiable(problems),
    training: training,
    contests: List.unmodifiable(contests),
  );
}

Map<String, dynamic> _buildCoreData({
  required List<ProblemRecord> problems,
  required TrainingStoreData training,
  required List<ContestRecord> contests,
}) {
  return {
    'problems': problems.map((item) => item.toStorageJson()).toList(),
    'training': training.toJson(),
    'contests': contests.map((item) => item.toStorageJson()).toList(),
  };
}

Map<String, dynamic> _buildBackupDocument({
  required DateTime createdAt,
  required String backupType,
  required String contentHash,
  required Map<String, dynamic> data,
}) {
  return {
    'schemaVersion': automaticBackupSchemaVersion,
    'app': 'oj_float',
    'backupScope': automaticBackupScope,
    'backupType': backupType,
    'createdAt': createdAt.toIso8601String(),
    'contentHash': contentHash,
    'data': data,
  };
}

String _contentHash(Map<String, dynamic> data) {
  final canonical = jsonEncode(_canonicalize(data));
  return 'sha256:${sha256.convert(utf8.encode(canonical))}';
}

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return {
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is List) {
    return value.map(_canonicalize).toList();
  }
  return value;
}

List<ProblemRecord> _parseProblemsStrict(Object? value) {
  if (value is! List) {
    throw const FormatException('Backup problems are invalid.');
  }
  final problems = <ProblemRecord>[];
  for (final item in value) {
    if (item is! Map) {
      throw const FormatException('Backup problem entry is invalid.');
    }
    final problem = ProblemRecord.tryFromJson(
      Map<String, dynamic>.from(item),
    );
    if (problem == null) {
      throw const FormatException('Backup problem entry is invalid.');
    }
    problems.add(problem);
  }
  return problems;
}

List<ContestRecord> _parseContestsStrict(Object? value) {
  if (value is! List) {
    throw const FormatException('Backup contests are invalid.');
  }
  final contests = <ContestRecord>[];
  for (final item in value) {
    if (item is! Map) {
      throw const FormatException('Backup contest entry is invalid.');
    }
    final contest = ContestRecord.tryFromJson(
      Map<String, dynamic>.from(item),
    );
    if (contest == null) {
      throw const FormatException('Backup contest entry is invalid.');
    }
    contests.add(contest);
  }
  return contests;
}

TrainingStoreData _parseTrainingStrict(Object? value) {
  if (value is! Map) {
    throw const FormatException('Backup training data is invalid.');
  }
  final json = Map<String, dynamic>.from(value);
  final rawAttempts = json['attempts'];
  final rawLists = json['lists'];
  final rawTasks = json['tasks'];
  if (rawAttempts is! List || rawLists is! List || rawTasks is! List) {
    throw const FormatException('Backup training collections are invalid.');
  }
  final training = TrainingStoreData.tryFromJson(json);
  if (training == null ||
      training.attempts.length != rawAttempts.length ||
      training.lists.length != rawLists.length ||
      training.tasks.length != rawTasks.length ||
      (json['activeAttempt'] != null && training.activeAttempt == null)) {
    throw const FormatException('Backup training entry is invalid.');
  }
  return training;
}

void _requireUnique(Iterable<String> ids, String label) {
  final values = ids.toList();
  if (values.toSet().length != values.length) {
    throw FormatException('Backup contains duplicate $label IDs.');
  }
}

void _validateCoreRelationships(
  List<ProblemRecord> problems,
  TrainingStoreData training,
) {
  final problemIds = problems.map((item) => item.id).toSet();
  for (final attempt in training.attempts) {
    if (!problemIds.contains(attempt.problemId)) {
      throw const FormatException(
        'Backup attempt refers to a missing problem.',
      );
    }
  }
  for (final list in training.lists) {
    if (list.problemIds.any((id) => !problemIds.contains(id))) {
      throw const FormatException(
        'Backup list refers to a missing problem.',
      );
    }
  }
  final tasksById = <String, DailyTrainingTask>{};
  for (final task in training.tasks) {
    if (!problemIds.contains(task.problemId)) {
      throw const FormatException(
        'Backup schedule refers to a missing problem.',
      );
    }
    tasksById[task.id] = task;
  }
  if (training.lists.where((item) => item.isDefault).length != 1) {
    throw const FormatException(
      'Backup must contain exactly one default favorites list.',
    );
  }
  final active = training.activeAttempt;
  if (active == null) {
    return;
  }
  if (!problemIds.contains(active.problemId)) {
    throw const FormatException(
      'Backup active timer refers to a missing problem.',
    );
  }
  if (active.taskId != null) {
    final task = tasksById[active.taskId];
    if (task == null ||
        task.problemId != active.problemId ||
        task.status != DailyTaskStatus.inProgress) {
      throw const FormatException(
        'Backup active timer does not match its schedule task.',
      );
    }
  }
}

bool _isAutomaticBackupFile(String path) {
  final name = path.split(Platform.pathSeparator).last;
  return name.startsWith('oj_float_auto_backup_') && name.endsWith('.json');
}

Future<File> _availableBackupFile(Directory directory, DateTime time) async {
  final base = 'oj_float_auto_backup_${_timestamp(time)}';
  var suffix = 0;
  while (true) {
    final name = suffix == 0 ? '$base.json' : '${base}_$suffix.json';
    final file = File('${directory.path}${Platform.pathSeparator}$name');
    if (!await file.exists() && !await File('${file.path}.tmp').exists()) {
      return file;
    }
    suffix++;
  }
}

String _timestamp(DateTime time) {
  final local = time.toLocal();
  return '${local.year.toString().padLeft(4, '0')}'
      '${local.month.toString().padLeft(2, '0')}'
      '${local.day.toString().padLeft(2, '0')}_'
      '${local.hour.toString().padLeft(2, '0')}'
      '${local.minute.toString().padLeft(2, '0')}'
      '${local.second.toString().padLeft(2, '0')}';
}

String _weekStartKey(DateTime time) {
  final local = time.toLocal();
  final day = DateTime(local.year, local.month, local.day);
  return dateKey(day.subtract(Duration(days: day.weekday - DateTime.monday)));
}

class _StoredAutomaticBackup {
  const _StoredAutomaticBackup({required this.file, required this.backup});

  final File file;
  final CoreTrainingBackup backup;
}

class _BackupScan {
  const _BackupScan({required this.valid, required this.invalidCount});

  final List<_StoredAutomaticBackup> valid;
  final int invalidCount;
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
