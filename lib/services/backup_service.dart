import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../core/oj_catalog.dart';
import '../models/app_config.dart';
import '../models/contest_record.dart';
import '../models/fetch_result.dart';
import '../models/problem_record.dart';
import '../models/solved_snapshot.dart';
import '../models/teammate.dart';
import '../models/training.dart';
import 'daily_summary_service.dart';
import 'local_store.dart';

class ExportResult {
  const ExportResult({
    required this.directory,
    required this.backupFile,
    required this.dailySummaryFile,
  });

  final Directory directory;
  final File backupFile;
  final File dailySummaryFile;
}

enum BackupImportScope { portable, coreTraining }

class ImportResult {
  const ImportResult({
    required this.safetyBackupFile,
    required this.scope,
  });

  final File safetyBackupFile;
  final BackupImportScope scope;
}

class ParsedPortableBackup {
  const ParsedPortableBackup({
    required this.config,
    required this.snapshots,
    required this.problems,
    required this.contests,
    required this.teammates,
    required this.training,
  });

  final AppConfig config;
  final List<SolvedSnapshot> snapshots;
  final List<ProblemRecord> problems;
  final List<ContestRecord> contests;
  final TeammateStoreData teammates;
  final TrainingStoreData training;
}

Future<ExportResult> exportOjData({
  required AppConfig config,
  required List<SolvedSnapshot> snapshots,
  List<ProblemRecord> problems = const [],
  List<ContestRecord> contests = const [],
  TeammateStoreData teammates = const TeammateStoreData(),
  TrainingStoreData training = const TrainingStoreData(),
  DateTime? now,
  Directory? directory,
  String prefix = 'oj_float_backup',
  bool writeDailySummary = true,
}) async {
  final exportTime = now ?? DateTime.now();
  final exportDirectory = directory ?? await exportDirectoryForOjData();
  await exportDirectory.create(recursive: true);

  final backupFile = await _availableExportFile(
    exportDirectory,
    prefix,
    'json',
    exportTime,
  );
  final dailySummaryFile = await _availableExportFile(
    exportDirectory,
    'oj_float_daily_summary',
    'csv',
    exportTime,
  );

  final backupText = buildPortableBackupJson(
    config: config,
    snapshots: snapshots,
    problems: problems,
    contests: contests,
    teammates: teammates,
    training: training,
    exportedAt: exportTime,
  );
  await _writeVerifiedPortableBackup(backupFile, backupText);
  if (writeDailySummary) {
    await dailySummaryFile.writeAsString(
      buildDailySummaryCsv(snapshots),
      flush: true,
    );
  }

  return ExportResult(
    directory: exportDirectory,
    backupFile: backupFile,
    dailySummaryFile: dailySummaryFile,
  );
}

Future<Directory> exportDirectoryForOjData() async {
  try {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) {
      return downloads;
    }
  } on MissingPluginException {
    // Widget tests do not load the desktop path provider plugin.
  }
  final support = await getApplicationSupportDirectory();
  return Directory('${support.path}${Platform.pathSeparator}exports');
}

String buildPortableBackupJson({
  required AppConfig config,
  required List<SolvedSnapshot> snapshots,
  List<ProblemRecord> problems = const [],
  List<ContestRecord> contests = const [],
  TeammateStoreData teammates = const TeammateStoreData(),
  TrainingStoreData training = const TrainingStoreData(),
  required DateTime exportedAt,
}) {
  final retainedSnapshots = retainRecentSnapshots(snapshots);
  return const JsonEncoder.withIndent('  ').convert(
    {
      'schemaVersion': 2,
      'app': 'oj_float',
      'exportType': 'portable_backup',
      'exportedAt': exportedAt.toIso8601String(),
      'config': buildPortableConfigJson(config),
      'snapshots':
          retainedSnapshots.map((snapshot) => snapshot.toJson()).toList(),
      'problems': problems.map((problem) => problem.toStorageJson()).toList(),
      'contests': contests.map((contest) => contest.toStorageJson()).toList(),
      'teammates': trimTeammateStoreData(teammates, now: exportedAt).toJson(),
      'training': training.toJson(),
      'dailyStats': buildDailyStatsJson(retainedSnapshots),
    },
  );
}

ParsedPortableBackup parsePortableBackupJson(String jsonText) {
  final decoded = jsonDecode(jsonText);
  if (decoded is! Map) {
    throw const FormatException('备份 JSON 必须是对象。');
  }
  final data = Map<String, dynamic>.from(decoded);
  final schemaVersion = data['schemaVersion'];
  if (schemaVersion != 1 && schemaVersion != 2) {
    throw const FormatException('备份版本不受支持。');
  }
  if (data['app'] != 'oj_float') {
    throw const FormatException('备份所属应用不匹配。');
  }
  if (data['exportType'] != 'portable_backup') {
    throw const FormatException('备份类型不是便携备份。');
  }
  final exportedAt = data['exportedAt'];
  final parsedExportedAt =
      exportedAt is String ? DateTime.tryParse(exportedAt) : null;
  final rawConfig = data['config'];
  if (rawConfig is! Map) {
    throw const FormatException('备份缺少配置或配置无效。');
  }
  final rawSnapshots = data['snapshots'];
  if (rawSnapshots is! List) {
    throw const FormatException('备份快照必须是数组。');
  }

  final snapshots = <SolvedSnapshot>[];
  for (final item in rawSnapshots) {
    try {
      if (item is! Map) {
        continue;
      }
      final snapshot = SolvedSnapshot.tryFromJson(
        Map<String, dynamic>.from(item),
      );
      if (snapshot != null) {
        snapshots.add(snapshot);
      }
    } catch (_) {
      continue;
    }
  }
  final rawProblems = data['problems'];
  final problems = <ProblemRecord>[];
  if (rawProblems != null) {
    if (rawProblems is! List) {
      throw const FormatException('备份题单必须是数组。');
    }
    for (final item in rawProblems) {
      try {
        if (item is! Map) {
          continue;
        }
        final problem = ProblemRecord.tryFromJson(
          Map<String, dynamic>.from(item),
        );
        if (problem != null) {
          problems.add(problem);
        }
      } catch (_) {
        continue;
      }
    }
  }
  problems.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  final rawContests = data['contests'];
  final contests = <ContestRecord>[];
  if (rawContests != null) {
    if (rawContests is! List) {
      throw const FormatException('备份比赛记录必须是数组。');
    }
    for (final item in rawContests) {
      try {
        if (item is! Map) {
          continue;
        }
        final contest = ContestRecord.tryFromJson(
          Map<String, dynamic>.from(item),
        );
        if (contest != null) {
          contests.add(contest);
        }
      } catch (_) {
        continue;
      }
    }
  }
  contests.sort((a, b) {
    final byDate = b.date.compareTo(a.date);
    if (byDate != 0) {
      return byDate;
    }
    return b.updatedAt.compareTo(a.updatedAt);
  });

  final rawTeammates = data['teammates'];
  var teammates = const TeammateStoreData();
  if (rawTeammates != null) {
    if (rawTeammates is! Map) {
      throw const FormatException('备份队友数据必须是对象。');
    }
    teammates = TeammateStoreData.tryFromJson(
          Map<String, dynamic>.from(rawTeammates),
        ) ??
        const TeammateStoreData();
    teammates = trimTeammateStoreData(
      teammates,
      now: parsedExportedAt ?? _latestTeammateDate(teammates),
    );
  }

  var training = const TrainingStoreData();
  final rawTraining = data['training'];
  if (rawTraining != null) {
    if (rawTraining is! Map) {
      throw const FormatException('备份训练数据必须是对象。');
    }
    training = TrainingStoreData.tryFromJson(
          Map<String, dynamic>.from(rawTraining),
        ) ??
        const TrainingStoreData();
  }

  return ParsedPortableBackup(
    config: AppConfig.fromPortableJson(Map<String, dynamic>.from(rawConfig)),
    snapshots: retainRecentSnapshots(snapshots),
    problems: List.unmodifiable(problems),
    contests: List.unmodifiable(contests),
    teammates: teammates,
    training: training,
  );
}

DateTime _latestTeammateDate(TeammateStoreData teammates) {
  final dates = <String>[
    ...teammates.records.map((record) => record.trainingDate),
    ...teammates.snapshots.map((snapshot) => snapshot.trainingDate),
  ]..sort();
  if (dates.isEmpty) {
    return DateTime.now();
  }
  return DateTime.parse('${dates.last}T12:00:00');
}

Map<String, Object?> buildPortableConfigJson(AppConfig config) {
  return {
    'refreshIntervalMinutes': config.refreshIntervalMinutes,
    'dashboardModules':
        config.dashboardModules.map((module) => module.id).toList(),
    'colorTheme': config.colorTheme.id,
    'accounts': [
      for (final meta in supportedOjs)
        {
          'ojId': meta.id,
          'enabled': config.accounts[meta.id]?.enabled ?? false,
          'usernames': config.accounts[meta.id]?.usernames ?? const <String>[],
        },
    ],
  };
}

List<Map<String, Object?>> buildDailyStatsJson(List<SolvedSnapshot> snapshots) {
  final dates = {
    for (final snapshot in snapshots)
      if (snapshot.status == FetchStatus.success) snapshot.date,
  }.toList()
    ..sort();
  return [
    for (final date in dates) _dailyStatJson(date, snapshots),
  ];
}

Map<String, Object?> _dailyStatJson(
  String date,
  List<SolvedSnapshot> snapshots,
) {
  final totalDelta = DailySummary.fromSnapshots(date, snapshots).totalDelta;
  return {
    'date': date,
    'totalDelta': totalDelta,
    'active': totalDelta > 0,
  };
}

String buildDailySummaryCsv(List<SolvedSnapshot> snapshots) {
  final buffer = StringBuffer('date,totalDelta,active\n');
  for (final stat in buildDailyStatsJson(snapshots)) {
    buffer.writeln('${stat['date']},${stat['totalDelta']},${stat['active']}');
  }
  return buffer.toString();
}

String buildExportFileName(String prefix, String extension, DateTime time) {
  final local = time.toLocal();
  final timestamp = '${local.year.toString().padLeft(4, '0')}'
      '${local.month.toString().padLeft(2, '0')}'
      '${local.day.toString().padLeft(2, '0')}_'
      '${local.hour.toString().padLeft(2, '0')}'
      '${local.minute.toString().padLeft(2, '0')}';
  return '${prefix}_$timestamp.$extension';
}

Future<File> _availableExportFile(
  Directory directory,
  String prefix,
  String extension,
  DateTime time,
) async {
  final baseName = buildExportFileName(prefix, extension, time);
  final dot = baseName.lastIndexOf('.');
  final stem = dot < 0 ? baseName : baseName.substring(0, dot);
  final suffix = dot < 0 ? '' : baseName.substring(dot);
  var index = 0;
  while (true) {
    final name = index == 0 ? baseName : '${stem}_$index$suffix';
    final file = File('${directory.path}${Platform.pathSeparator}$name');
    if (!await file.exists() && !await File('${file.path}.tmp').exists()) {
      return file;
    }
    index++;
  }
}

Future<void> _writeVerifiedPortableBackup(File target, String text) async {
  final temporary = File('${target.path}.tmp');
  try {
    await temporary.writeAsString(text, flush: true);
    parsePortableBackupJson(await temporary.readAsString());
    await temporary.rename(target.path);
  } catch (_) {
    if (await temporary.exists()) {
      await temporary.delete();
    }
    rethrow;
  }
}
