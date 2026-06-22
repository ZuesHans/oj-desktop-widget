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

class LocalStore {
  LocalStore({Directory? supportDirectory})
      : _supportDirectory = supportDirectory;

  static const _configKey = 'app_config_v1';
  static const _snapshotsFile = 'snapshots_v1.json';
  static const _problemsFile = 'problems_v1.json';
  static const _contestsFile = 'contests_v1.json';
  static const _teammatesFile = 'teammates_v1.json';
  static const _refreshLogsFile = 'refresh_logs_v1.json';
  static const _maxRefreshLogs = 200;

  final Directory? _supportDirectory;

  Future<AppConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_configKey);
    if (raw == null) {
      return AppConfig.defaults();
    }
    try {
      final data = jsonDecode(raw);
      if (data is! Map) {
        debugPrint('Invalid app config JSON: expected an object.');
        return AppConfig.defaults();
      }
      return AppConfig.fromJson(Map<String, dynamic>.from(data));
    } catch (_) {
      debugPrint('Failed to parse app config. Using defaults.');
      return AppConfig.defaults();
    }
  }

  Future<void> saveConfig(AppConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, jsonEncode(config.toJson()));
  }

  Future<List<SolvedSnapshot>> loadSnapshots() async {
    final file = await _snapshotFile();
    if (!await file.exists()) {
      return [];
    }
    try {
      final data = jsonDecode(await file.readAsString());
      if (data is! List) {
        debugPrint('Invalid snapshots JSON: expected a list.');
        return [];
      }
      final snapshots = <SolvedSnapshot>[];
      for (final item in data) {
        try {
          if (item is! Map) {
            debugPrint('Skipping invalid snapshot: expected an object.');
            continue;
          }
          final snapshot = SolvedSnapshot.tryFromJson(
            Map<String, dynamic>.from(item),
          );
          if (snapshot == null) {
            debugPrint('Skipping invalid snapshot entry.');
            continue;
          }
          snapshots.add(snapshot);
        } catch (_) {
          debugPrint('Skipping invalid snapshot entry.');
          continue;
        }
      }
      return snapshots;
    } catch (_) {
      debugPrint('Failed to parse snapshots. Using an empty list.');
      return [];
    }
  }

  Future<void> saveSnapshots(List<SolvedSnapshot> snapshots) async {
    final file = await _snapshotFile();
    await file.parent.create(recursive: true);
    final kept = snapshots.length > 6000
        ? snapshots.sublist(snapshots.length - 6000)
        : snapshots;
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        kept.map((item) => item.toJson()).toList(),
      ),
    );
  }

  Future<void> replaceSnapshots(List<SolvedSnapshot> snapshots) async {
    final file = await _snapshotFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        snapshots.map((item) => item.toJson()).toList(),
      ),
    );
  }

  Future<List<RefreshLogEntry>> loadRefreshLogs() async {
    final file = await _refreshLogsFileHandle();
    if (!await file.exists()) {
      return [];
    }
    try {
      final data = jsonDecode(await file.readAsString());
      if (data is! List) {
        debugPrint('Invalid refresh logs JSON: expected a list.');
        return [];
      }
      final entries = <RefreshLogEntry>[];
      for (final item in data) {
        try {
          if (item is! Map) {
            debugPrint('Skipping invalid refresh log: expected an object.');
            continue;
          }
          final entry = RefreshLogEntry.tryFromJson(
            Map<String, dynamic>.from(item),
          );
          if (entry == null) {
            debugPrint('Skipping invalid refresh log entry.');
            continue;
          }
          entries.add(entry);
        } catch (_) {
          debugPrint('Skipping invalid refresh log entry.');
        }
      }
      entries.sort((a, b) => b.fetchedAt.compareTo(a.fetchedAt));
      return List.unmodifiable(entries.take(_maxRefreshLogs).toList());
    } catch (_) {
      debugPrint('Failed to parse refresh logs. Using an empty list.');
      return [];
    }
  }

  Future<void> saveRefreshLogs(List<RefreshLogEntry> entries) async {
    final file = await _refreshLogsFileHandle();
    await file.parent.create(recursive: true);
    final sorted = [...entries]
      ..sort((a, b) => b.fetchedAt.compareTo(a.fetchedAt));
    final kept = sorted.take(_maxRefreshLogs).toList();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        kept.map((item) => item.toJson()).toList(),
      ),
    );
  }

  Future<List<ProblemRecord>> loadProblems() async {
    final file = await _problemsFileHandle();
    if (!await file.exists()) {
      return [];
    }
    try {
      final data = jsonDecode(await file.readAsString());
      if (data is! List) {
        debugPrint('Invalid problems JSON: expected a list.');
        return [];
      }
      final problems = <ProblemRecord>[];
      for (final item in data) {
        try {
          if (item is! Map) {
            debugPrint('Skipping invalid problem: expected an object.');
            continue;
          }
          final problem = ProblemRecord.tryFromJson(
            Map<String, dynamic>.from(item),
          );
          if (problem == null) {
            debugPrint('Skipping invalid problem entry.');
            continue;
          }
          problems.add(problem);
        } catch (_) {
          debugPrint('Skipping invalid problem entry.');
        }
      }
      problems.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return List.unmodifiable(problems);
    } catch (_) {
      debugPrint('Failed to parse problems. Using an empty list.');
      return [];
    }
  }

  Future<void> saveProblems(List<ProblemRecord> problems) async {
    final file = await _problemsFileHandle();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        problems.map((item) => item.toStorageJson()).toList(),
      ),
    );
  }

  Future<void> replaceProblems(List<ProblemRecord> problems) =>
      saveProblems(problems);

  Future<List<ContestRecord>> loadContests() async {
    final file = await _contestsFileHandle();
    if (!await file.exists()) {
      return [];
    }
    try {
      final data = jsonDecode(await file.readAsString());
      if (data is! List) {
        debugPrint('Invalid contests JSON: expected a list.');
        return [];
      }
      final contests = <ContestRecord>[];
      for (final item in data) {
        try {
          if (item is! Map) {
            debugPrint('Skipping invalid contest: expected an object.');
            continue;
          }
          final contest = ContestRecord.tryFromJson(
            Map<String, dynamic>.from(item),
          );
          if (contest == null) {
            debugPrint('Skipping invalid contest entry.');
            continue;
          }
          contests.add(contest);
        } catch (_) {
          debugPrint('Skipping invalid contest entry.');
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
      debugPrint('Failed to parse contests. Using an empty list.');
      return [];
    }
  }

  Future<void> saveContests(List<ContestRecord> contests) async {
    final file = await _contestsFileHandle();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        contests.map((item) => item.toStorageJson()).toList(),
      ),
    );
  }

  Future<void> replaceContests(List<ContestRecord> contests) =>
      saveContests(contests);

  Future<TeammateStoreData> loadTeammates() async {
    final file = await _teammatesFileHandle();
    if (!await file.exists()) {
      return const TeammateStoreData();
    }
    try {
      final data = jsonDecode(await file.readAsString());
      if (data is! Map) {
        debugPrint('Invalid teammates JSON: expected an object.');
        return const TeammateStoreData();
      }
      return TeammateStoreData.tryFromJson(Map<String, dynamic>.from(data)) ??
          const TeammateStoreData();
    } catch (_) {
      debugPrint('Failed to parse teammates. Using an empty list.');
      return const TeammateStoreData();
    }
  }

  Future<void> saveTeammates(TeammateStoreData teammates) async {
    final file = await _teammatesFileHandle();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        trimTeammateStoreData(teammates).toJson(),
      ),
    );
  }

  Future<void> replaceTeammates(TeammateStoreData teammates) async {
    final file = await _teammatesFileHandle();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(teammates.toJson()),
    );
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
}
