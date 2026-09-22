import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oj_float/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _configKey = 'app_config_v1';
const _snapshotsFile = 'snapshots_v1.json';
const _refreshLogsFile = 'refresh_logs_v1.json';
const _contestsFile = 'contests_v1.json';
const _trainingFile = 'training_v1.json';
const _problemTrainingTransactionFile = 'problem_training_transaction_v1.json';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('config storage hardening', () {
    test('damaged config JSON falls back to defaults', () async {
      SharedPreferences.setMockInitialValues({_configKey: '{not-json'});

      final config = await LocalStore().loadConfig();

      expect(config.refreshIntervalMinutes, 60);
      expect(config.accounts.length, supportedOjs.length);
      expect(
          config.accounts.values.every((account) => !account.enabled), isTrue);
    });

    test('missing refreshIntervalMinutes falls back to 60', () {
      final config = AppConfig.fromJson({'accounts': <String, dynamic>{}});

      expect(config.refreshIntervalMinutes, 60);
    });

    test('refreshIntervalMinutes of zero falls back to 60', () {
      final config = AppConfig.fromJson({'refreshIntervalMinutes': 0});

      expect(config.refreshIntervalMinutes, 60);
    });

    test('negative refreshIntervalMinutes falls back to 60', () {
      final config = AppConfig.fromJson({'refreshIntervalMinutes': -1});

      expect(config.refreshIntervalMinutes, 60);
    });

    test('refreshIntervalMinutes above 1440 falls back to 60', () {
      final config = AppConfig.fromJson({'refreshIntervalMinutes': 1441});

      expect(config.refreshIntervalMinutes, 60);
    });

    test('wrong refreshIntervalMinutes type falls back to 60', () {
      final config = AppConfig.fromJson({'refreshIntervalMinutes': '60'});

      expect(config.refreshIntervalMinutes, 60);
    });

    test('old username field is read as a single username', () {
      final config = AppConfig.fromJson({
        'accounts': {
          'codeforces': {'username': 'abc', 'enabled': true},
        },
      });

      expect(config.accounts['codeforces']!.usernames, ['abc']);
      expect(config.accounts['codeforces']!.enabled, isTrue);
    });

    test('new usernames field is read as multiple usernames', () {
      final config = AppConfig.fromJson({
        'accounts': {
          'codeforces': {
            'usernames': ['a', 'b'],
            'enabled': true,
          },
        },
      });

      expect(config.accounts['codeforces']!.usernames, ['a', 'b']);
      expect(config.accounts['codeforces']!.enabled, isTrue);
    });

    test('comma-separated usernames are normalized', () {
      final usernames = OjAccountConfig.normalizeUsernames(['a, b,,a']);

      expect(usernames, ['a', 'b']);
    });

    test('dashboard module order keeps known visible items', () {
      final config = AppConfig.fromJson({
        'dashboardModules': [
          'teammates',
          'heatmap',
          'unknown',
          'teammates',
        ],
      });

      expect(config.dashboardModules.take(2), [
        DashboardModule.teammates,
        DashboardModule.heatmap,
      ]);
      expect(config.dashboardModules, hasLength(2));
    });

    test('missing dashboard modules use default client modules', () {
      final config = AppConfig.fromJson({});

      expect(config.dashboardModules.toSet(), defaultDashboardModules.toSet());
    });

    test('legacy floating config migrates once and preserves business data',
        () async {
      SharedPreferences.setMockInitialValues({
        _configKey: jsonEncode({
          'refreshIntervalMinutes': 45,
          'launchAtStartup': true,
          'closeToTray': true,
          'alwaysOnTop': true,
          'showInTaskbar': false,
          'compactClickTarget': 'dashboard',
          'colorTheme': 'ocean',
          'dashboardModules': ['teammates', 'heatmap'],
          'sync': {
            'enabled': true,
            'endpointUrl': 'https://example.com/sync',
          },
          'accounts': {
            'codeforces': {
              'usernames': ['alice', 'bob'],
              'enabled': true,
            },
          },
        }),
      });

      final store = LocalStore();
      final migrated = await store.loadConfig();

      expect(migrated.configVersion, currentAppConfigVersion);
      expect(migrated.closeToTray, isFalse);
      expect(migrated.launchAtStartup, isFalse);
      expect(migrated.refreshIntervalMinutes, 45);
      expect(migrated.colorTheme, AppColorTheme.githubLight);
      expect(migrated.dashboardModules, [
        DashboardModule.teammates,
        DashboardModule.heatmap,
      ]);
      expect(migrated.sync.enabled, isTrue);
      expect(migrated.accounts['codeforces']!.usernames, ['alice', 'bob']);

      final prefs = await SharedPreferences.getInstance();
      final persisted =
          jsonDecode(prefs.getString(_configKey)!) as Map<String, dynamic>;
      expect(persisted['configVersion'], currentAppConfigVersion);
      expect(persisted.containsKey('alwaysOnTop'), isFalse);
      expect(persisted.containsKey('showInTaskbar'), isFalse);
      expect(persisted.containsKey('compactClickTarget'), isFalse);

      await store.saveConfig(
        migrated.copyWith(closeToTray: true, launchAtStartup: true),
      );
      final reloaded = await store.loadConfig();
      expect(reloaded.closeToTray, isTrue);
      expect(reloaded.launchAtStartup, isTrue);
    });
  });

  group('snapshot storage hardening', () {
    test('damaged primary file recovers the previous atomic backup', () async {
      final directory = await Directory.systemTemp.createTemp('oj_float_test_');
      final file =
          File('${directory.path}${Platform.pathSeparator}$_snapshotsFile');
      try {
        final store = LocalStore(supportDirectory: directory);
        final first = SolvedSnapshot.fromJson(_validSnapshot());
        final second = SolvedSnapshot.fromJson({
          ..._validSnapshot(),
          'solvedCount': 99,
          'fetchedAt': '2026-06-15T09:00:00.000',
        });
        await store.saveSnapshots([first]);
        await store.saveSnapshots([second]);
        await file.writeAsString('{damaged');

        final recovered = await store.loadSnapshots();

        expect(recovered.single.solvedCount, 42);
        expect(jsonDecode(await file.readAsString()), isA<List<dynamic>>());
        expect(File('${file.path}.tmp').existsSync(), isFalse);
      } finally {
        await directory.delete(recursive: true);
      }
    });

    test('damaged snapshot file falls back to an empty list', () async {
      final directory = await Directory.systemTemp.createTemp('oj_float_test_');
      try {
        await File('${directory.path}${Platform.pathSeparator}$_snapshotsFile')
            .writeAsString('{not-json');

        final snapshots =
            await LocalStore(supportDirectory: directory).loadSnapshots();

        expect(snapshots, isEmpty);
      } finally {
        await directory.delete(recursive: true);
      }
    });

    test('damaged snapshot entry is skipped while valid entries are kept',
        () async {
      final snapshots = await _loadSnapshotsFromJson([
        _validSnapshot(),
        {
          'date': '2026-06-15',
          'fetchedAt': 123,
          'ojId': 'codeforces',
          'status': 'success',
        },
        {
          'date': '2026-06-15',
          'fetchedAt': '2026-06-15T09:00:00.000',
          'status': 'success',
        },
      ]);

      expect(snapshots, hasLength(1));
      expect(snapshots.single.ojId, 'codeforces');
      expect(snapshots.single.solvedCount, 42);
    });

    test('snapshot with unknown status is skipped', () async {
      final snapshots = await _loadSnapshotsFromJson([
        _validSnapshot(status: 'mystery'),
      ]);

      expect(snapshots, isEmpty);
    });

    test('snapshot with invalid date is skipped', () async {
      final snapshots = await _loadSnapshotsFromJson([
        _validSnapshot(date: '2026-02-31'),
        _validSnapshot(ojId: 'leetcode'),
      ]);

      expect(snapshots, hasLength(1));
      expect(snapshots.single.ojId, 'leetcode');
    });

    test('snapshot missing username is kept with an empty username', () async {
      final snapshot = _validSnapshot()..remove('username');

      final snapshots = await _loadSnapshotsFromJson([snapshot]);

      expect(snapshots, hasLength(1));
      expect(snapshots.single.username, '');
    });

    test('loading trims memory and disk to the latest 6000 snapshots',
        () async {
      final directory = await Directory.systemTemp.createTemp('oj_float_test_');
      final file =
          File('${directory.path}${Platform.pathSeparator}$_snapshotsFile');
      final base = DateTime.parse('2026-01-01T00:00:00');
      try {
        await file.writeAsString(jsonEncode([
          for (var i = 6004; i >= 0; i--)
            {
              ..._validSnapshot(),
              'fetchedAt': base.add(Duration(minutes: i)).toIso8601String(),
              'solvedCount': i,
            },
        ]));

        final snapshots =
            await LocalStore(supportDirectory: directory).loadSnapshots();
        final persisted =
            jsonDecode(await file.readAsString()) as List<dynamic>;

        expect(snapshots, hasLength(maxStoredSnapshots));
        expect(snapshots.first.solvedCount, 5);
        expect(snapshots.last.solvedCount, 6004);
        expect(persisted, hasLength(maxStoredSnapshots));
      } finally {
        await directory.delete(recursive: true);
      }
    });
  });

  group('refresh log storage hardening', () {
    test('damaged refresh log file falls back to an empty list', () async {
      final directory = await Directory.systemTemp.createTemp('oj_float_test_');
      try {
        await File(
          '${directory.path}${Platform.pathSeparator}$_refreshLogsFile',
        ).writeAsString('{not-json');

        final logs =
            await LocalStore(supportDirectory: directory).loadRefreshLogs();

        expect(logs, isEmpty);
      } finally {
        await directory.delete(recursive: true);
      }
    });

    test('refresh logs keep only the latest 200 entries', () async {
      final directory = await Directory.systemTemp.createTemp('oj_float_test_');
      try {
        final store = LocalStore(supportDirectory: directory);
        final base = DateTime.parse('2026-06-15T08:00:00');
        await store.saveRefreshLogs([
          for (var i = 0; i < 205; i++)
            RefreshLogEntry.create(
              fetchedAt: base.add(Duration(minutes: i)),
              ojId: 'codeforces',
              username: 'alice',
              status: RefreshLogStatus.success,
              source: 'primary',
              message: 'ok $i',
              solvedCount: i,
            ),
        ]);

        final logs = await store.loadRefreshLogs();

        expect(logs, hasLength(200));
        expect(logs.first.solvedCount, 204);
        expect(logs.last.solvedCount, 5);
      } finally {
        await directory.delete(recursive: true);
      }
    });
  });

  test('training store persists an active timer', () async {
    final directory = await Directory.systemTemp.createTemp('oj_float_test_');
    try {
      final store = LocalStore(supportDirectory: directory);
      final active = ActiveTrainingAttempt.create(
        problemId: 'p1',
        origin: TrainingAttemptOrigin.manual,
        now: DateTime(2026, 7, 27, 8),
      );
      await store.saveTraining(TrainingStoreData(activeAttempt: active));

      final loaded = await store.loadTraining();

      expect(loaded.activeAttempt?.problemId, 'p1');
      expect(loaded.activeAttempt?.startedAt, DateTime(2026, 7, 27, 8));
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('problem and training transaction commits both files', () async {
    final directory = await Directory.systemTemp.createTemp('oj_float_test_');
    final transaction = File(
      '${directory.path}${Platform.pathSeparator}'
      '$_problemTrainingTransactionFile',
    );
    try {
      final store = LocalStore(supportDirectory: directory);
      final endedAt = DateTime(2026, 7, 27, 8, 10);
      final problem = _trainingProblem(
        workflowStatus: ProblemWorkflowStatus.mastered,
      );
      final training = TrainingStoreData(
        attempts: [
          TrainingAttempt.create(
            id: 'a1',
            problemId: problem.id,
            origin: TrainingAttemptOrigin.manual,
            startedAt: endedAt.subtract(const Duration(minutes: 10)),
            endedAt: endedAt,
            durationSeconds: 600,
            result: AttemptResult.ac,
          ),
        ],
      );

      await store.saveProblemsAndTraining([problem], training);

      expect((await store.loadProblems()).single.workflowStatus,
          ProblemWorkflowStatus.mastered);
      expect((await store.loadTraining()).attempts.single.id, 'a1');
      expect(await transaction.exists(), isFalse);
      expect(await File('${transaction.path}.bak').exists(), isFalse);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('pending problem and training transaction rolls forward on recovery',
      () async {
    final directory = await Directory.systemTemp.createTemp('oj_float_test_');
    final transaction = File(
      '${directory.path}${Platform.pathSeparator}'
      '$_problemTrainingTransactionFile',
    );
    try {
      final store = LocalStore(supportDirectory: directory);
      final oldProblem = _trainingProblem();
      await store.saveProblemsAndTraining(
        [oldProblem],
        const TrainingStoreData(),
      );

      final endedAt = DateTime(2026, 7, 27, 8, 10);
      final updatedProblem = oldProblem.copyWith(
        workflowStatus: ProblemWorkflowStatus.mastered,
        updatedAt: endedAt,
      );
      final updatedTraining = TrainingStoreData(
        attempts: [
          TrainingAttempt.create(
            id: 'recovered-attempt',
            problemId: oldProblem.id,
            origin: TrainingAttemptOrigin.manual,
            startedAt: endedAt.subtract(const Duration(minutes: 10)),
            endedAt: endedAt,
            durationSeconds: 600,
            result: AttemptResult.ac,
          ),
        ],
      );
      await transaction.writeAsString(
        jsonEncode({
          'schemaVersion': 1,
          'problems': [updatedProblem.toStorageJson()],
          'training': updatedTraining.toJson(),
        }),
        flush: true,
      );
      await store.saveProblems([updatedProblem]);

      final trainingBeforeRecovery = jsonDecode(
        await File(
          '${directory.path}${Platform.pathSeparator}$_trainingFile',
        ).readAsString(),
      ) as Map<String, dynamic>;
      expect(trainingBeforeRecovery['attempts'], isEmpty);

      await LocalStore(supportDirectory: directory)
          .recoverPendingProblemTrainingTransaction();

      final recoveredStore = LocalStore(supportDirectory: directory);
      expect((await recoveredStore.loadProblems()).single.workflowStatus,
          ProblemWorkflowStatus.mastered);
      expect(
        (await recoveredStore.loadTraining()).attempts.single.id,
        'recovered-attempt',
      );
      expect(await transaction.exists(), isFalse);
      expect(
        await File(
          '${directory.path}${Platform.pathSeparator}'
          '$problemDatabaseFileName',
        ).exists(),
        isTrue,
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('pending core transaction rolls problems, training and contests forward',
      () async {
    final directory = await Directory.systemTemp.createTemp('oj_float_test_');
    final transaction = File(
      '${directory.path}${Platform.pathSeparator}'
      '$_problemTrainingTransactionFile',
    );
    try {
      final store = LocalStore(supportDirectory: directory);
      final problem = _trainingProblem();
      final endedAt = DateTime(2026, 7, 27, 9);
      final training = TrainingStoreData(
        attempts: [
          TrainingAttempt.create(
            id: 'core-attempt',
            problemId: problem.id,
            origin: TrainingAttemptOrigin.manual,
            startedAt: endedAt.subtract(const Duration(minutes: 20)),
            endedAt: endedAt,
            durationSeconds: 1200,
            result: AttemptResult.ac,
          ),
        ],
      );
      final contest = ContestRecord.create(
        id: 'core-contest',
        title: 'Core contest',
        date: '2026-07-27',
        rank: 3,
        note: 'Recovered review',
        now: endedAt,
      );
      await transaction.writeAsString(
        jsonEncode({
          'schemaVersion': 2,
          'problems': [problem.toStorageJson()],
          'training': training.toJson(),
          'contests': [contest.toStorageJson()],
        }),
        flush: true,
      );

      await store.recoverPendingProblemTrainingTransaction();

      final snapshot = await store.loadCoreBackupSnapshot();
      expect(snapshot.problems.single.id, problem.id);
      expect(snapshot.training.attempts.single.id, 'core-attempt');
      expect(snapshot.contests.single.id, 'core-contest');
      expect(snapshot.contests.single.note, 'Recovered review');
      expect(await transaction.exists(), isFalse);
      expect(
        jsonDecode(
          await File(
            '${directory.path}${Platform.pathSeparator}$_contestsFile',
          ).readAsString(),
        ),
        isA<List<dynamic>>(),
      );
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('parse failure logs do not include raw sensitive JSON content',
      () async {
    final logs = <String>[];
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) {
        logs.add(message);
      }
    };

    final directory = await Directory.systemTemp.createTemp('oj_float_test_');
    try {
      const damagedConfig =
          '{"accounts":{"codeforces":{"username":"secret_user_123"}}';
      const damagedSnapshots =
          '[{"username":"secret_user_123","error":"private failure text"';
      SharedPreferences.setMockInitialValues({_configKey: damagedConfig});
      await File('${directory.path}${Platform.pathSeparator}$_snapshotsFile')
          .writeAsString(damagedSnapshots);

      await LocalStore().loadConfig();
      await LocalStore(supportDirectory: directory).loadSnapshots();

      final joinedLogs = logs.join('\n');
      expect(joinedLogs, isNot(contains('secret_user_123')));
      expect(joinedLogs, isNot(contains(damagedConfig)));
      expect(joinedLogs, isNot(contains(damagedSnapshots)));
      expect(joinedLogs, isNot(contains('private failure text')));
    } finally {
      debugPrint = originalDebugPrint;
      await directory.delete(recursive: true);
    }
  });
}

Future<List<SolvedSnapshot>> _loadSnapshotsFromJson(
    List<Object?> entries) async {
  final directory = await Directory.systemTemp.createTemp('oj_float_test_');
  try {
    await File('${directory.path}${Platform.pathSeparator}$_snapshotsFile')
        .writeAsString(jsonEncode(entries));

    return await LocalStore(supportDirectory: directory).loadSnapshots();
  } finally {
    await directory.delete(recursive: true);
  }
}

Map<String, Object?> _validSnapshot({
  String date = '2026-06-15',
  String status = 'success',
  String ojId = 'codeforces',
}) {
  return {
    'date': date,
    'fetchedAt': '2026-06-15T08:00:00.000',
    'ojId': ojId,
    'username': 'alice',
    'status': status,
    'solvedCount': 42,
    'error': null,
  };
}

ProblemRecord _trainingProblem({
  ProblemWorkflowStatus workflowStatus = ProblemWorkflowStatus.active,
}) {
  return ProblemRecord.create(
    id: 'training-problem',
    title: 'Training Problem',
    url: 'https://example.com/problem/training',
    platform: ProblemPlatform.other,
    workflowStatus: workflowStatus,
    now: DateTime(2026, 7, 27, 8),
  );
}
