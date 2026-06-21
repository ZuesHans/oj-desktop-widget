part of '../main.dart';

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

class ImportResult {
  const ImportResult({required this.safetyBackupFile});

  final File safetyBackupFile;
}

class ParsedPortableBackup {
  const ParsedPortableBackup({
    required this.config,
    required this.snapshots,
    required this.problems,
  });

  final AppConfig config;
  final List<SolvedSnapshot> snapshots;
  final List<ProblemRecord> problems;
}

Future<ExportResult> exportOjData({
  required AppConfig config,
  required List<SolvedSnapshot> snapshots,
  List<ProblemRecord> problems = const [],
  DateTime? now,
  Directory? directory,
  String prefix = 'oj_float_backup',
  bool writeDailySummary = true,
}) async {
  final exportTime = now ?? DateTime.now();
  final exportDirectory = directory ?? await exportDirectoryForOjData();
  await exportDirectory.create(recursive: true);

  final backupFile = File(
    '${exportDirectory.path}${Platform.pathSeparator}'
    '${buildExportFileName(prefix, 'json', exportTime)}',
  );
  final dailySummaryFile = File(
    '${exportDirectory.path}${Platform.pathSeparator}'
    '${buildExportFileName('oj_float_daily_summary', 'csv', exportTime)}',
  );

  await backupFile.writeAsString(
    buildPortableBackupJson(
      config: config,
      snapshots: snapshots,
      problems: problems,
      exportedAt: exportTime,
    ),
  );
  if (writeDailySummary) {
    await dailySummaryFile.writeAsString(buildDailySummaryCsv(snapshots));
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
  required DateTime exportedAt,
}) {
  return const JsonEncoder.withIndent('  ').convert(
    {
      'schemaVersion': 1,
      'app': 'oj_float',
      'exportType': 'portable_backup',
      'exportedAt': exportedAt.toIso8601String(),
      'config': buildPortableConfigJson(config),
      'snapshots': snapshots.map((snapshot) => snapshot.toJson()).toList(),
      'problems': problems.map((problem) => problem.toStorageJson()).toList(),
      'dailyStats': buildDailyStatsJson(snapshots),
    },
  );
}

ParsedPortableBackup parsePortableBackupJson(String jsonText) {
  final decoded = jsonDecode(jsonText);
  if (decoded is! Map) {
    throw const FormatException('Backup JSON must be an object.');
  }
  final data = Map<String, dynamic>.from(decoded);
  if (data['schemaVersion'] != 1) {
    throw const FormatException('Unsupported backup schemaVersion.');
  }
  if (data['app'] != 'oj_float') {
    throw const FormatException('Backup app does not match oj_float.');
  }
  if (data['exportType'] != 'portable_backup') {
    throw const FormatException('Backup exportType is not portable_backup.');
  }
  final rawConfig = data['config'];
  if (rawConfig is! Map) {
    throw const FormatException('Backup config is missing or invalid.');
  }
  final rawSnapshots = data['snapshots'];
  if (rawSnapshots is! List) {
    throw const FormatException('Backup snapshots must be an array.');
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
      throw const FormatException('Backup problems must be an array.');
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

  return ParsedPortableBackup(
    config: AppConfig.fromPortableJson(Map<String, dynamic>.from(rawConfig)),
    snapshots: List.unmodifiable(snapshots),
    problems: List.unmodifiable(problems),
  );
}

Map<String, Object?> buildPortableConfigJson(AppConfig config) {
  return {
    'refreshIntervalMinutes': config.refreshIntervalMinutes,
    'launchAtStartup': config.launchAtStartup,
    'alwaysOnTop': config.alwaysOnTop,
    'showInTaskbar': config.showInTaskbar,
    'closeToTray': config.closeToTray,
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
