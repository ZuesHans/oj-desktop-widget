import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:oj_float/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('valid backup JSON can be parsed', () {
    final backup = parsePortableBackupJson(_backupJson(
      config: _portableConfig('alice'),
      snapshots: [_snapshotJson('2026-06-16', 'alice', 10)],
    ));

    expect(backup.config.accounts['codeforces']!.usernames, ['alice']);
    expect(backup.snapshots, hasLength(1));
    expect(backup.problems, isEmpty);
    expect(backup.contests, isEmpty);
  });

  test('backup problems and contests are optional and parsed when present', () {
    final oldBackup = parsePortableBackupJson(_backupJson());
    expect(oldBackup.problems, isEmpty);
    expect(oldBackup.contests, isEmpty);

    final backup = parsePortableBackupJson(_backupJson(
      problems: [
        _problem().toStorageJson(),
        {'id': 'broken'}
      ],
      contests: [
        _contest(id: 'contest-new').toStorageJson(),
        {'id': 'broken'}
      ],
    ));
    expect(backup.problems, hasLength(1));
    expect(backup.contests, hasLength(1));
    expect(backup.contests.single.id, 'contest-new');
    expect(backup.problems.single.tags, ['贪心', '构造']);
  });

  test('schemaVersion mismatch is rejected', () {
    expect(
      () => parsePortableBackupJson(_backupJson(schemaVersion: 2)),
      throwsFormatException,
    );
  });

  test('app mismatch is rejected', () {
    expect(
      () => parsePortableBackupJson(_backupJson(app: 'other')),
      throwsFormatException,
    );
  });

  test('exportType mismatch is rejected', () {
    expect(
      () => parsePortableBackupJson(_backupJson(exportType: 'csv')),
      throwsFormatException,
    );
  });

  test('missing config is rejected', () {
    final data = jsonDecode(_backupJson()) as Map<String, dynamic>;
    data.remove('config');

    expect(
      () => parsePortableBackupJson(jsonEncode(data)),
      throwsFormatException,
    );
  });

  test('missing snapshots is rejected', () {
    final data = jsonDecode(_backupJson()) as Map<String, dynamic>;
    data.remove('snapshots');

    expect(
      () => parsePortableBackupJson(jsonEncode(data)),
      throwsFormatException,
    );
  });

  test('dailyStats are not used as import state', () {
    final backup = parsePortableBackupJson(_backupJson(
      snapshots: const [],
      dailyStats: [
        {'date': '2026-06-16', 'totalDelta': 999, 'active': true},
      ],
    ));

    expect(backup.snapshots, isEmpty);
    expect(HeatmapSummary.fromSnapshots(backup.snapshots).totalDelta, 0);
  });

  test('bad snapshot entries do not crash import parsing', () {
    final backup = parsePortableBackupJson(_backupJson(
      snapshots: [
        _snapshotJson('2026-06-16', 'alice', 10),
        {'date': 'broken'},
        'not-a-snapshot',
      ],
    ));

    expect(backup.snapshots, hasLength(1));
    expect(backup.snapshots.single.username, 'alice');
  });

  test('import replaces config and snapshots after safety backup', () async {
    final directory = await Directory.systemTemp.createTemp('oj_import_test_');
    try {
      final store = LocalStore(supportDirectory: directory);
      await store.saveConfig(_localConfig('old-user'));
      await store.replaceSnapshots([
        _snapshot('2026-06-15', 'old-user', 1),
      ]);
      await store.replaceProblems([_problem(id: 'old-problem')]);
      await store.replaceContests([_contest(id: 'old-contest')]);
      await store.saveRefreshLogs([
        _refreshLog(username: 'old-user'),
      ]);

      final controller = OjController(
        storage: store,
        service: RefreshService(client: http.Client(), providers: const {}),
        startupService: NoopStartupService(),
      );
      await controller.init();

      final importFile =
          File('${directory.path}${Platform.pathSeparator}backup.json');
      await importFile.writeAsString(_backupJson(
        config: _portableConfig('new-user'),
        snapshots: [_snapshotJson('2026-06-16', 'new-user', 7)],
        problems: [_problem(id: 'new-problem').toStorageJson()],
        contests: [_contest(id: 'new-contest').toStorageJson()],
        dailyStats: [
          {'date': '2026-01-01', 'totalDelta': 123, 'active': true},
        ],
      ));

      final result = await controller.importPortableBackup(
        importFile,
        safetyBackupDirectory: directory,
      );
      final loadedConfig = await store.loadConfig();
      final loadedSnapshots = await store.loadSnapshots();
      final loadedProblems = await store.loadProblems();
      final loadedContests = await store.loadContests();
      final loadedRefreshLogs = await store.loadRefreshLogs();

      expect(result.safetyBackupFile.path,
          contains('oj_float_pre_import_backup_'));
      expect(await result.safetyBackupFile.exists(), isTrue);
      expect(
          await result.safetyBackupFile.readAsString(), contains('old-user'));
      expect(loadedConfig.accounts['codeforces']!.usernames, ['new-user']);
      expect(loadedSnapshots, hasLength(1));
      expect(loadedSnapshots.single.username, 'new-user');
      expect(loadedProblems.map((item) => item.id), ['new-problem']);
      expect(loadedContests.map((item) => item.id), ['new-contest']);
      expect(loadedRefreshLogs, isEmpty);
      expect(controller.state.refreshLogs, isEmpty);
      expect(controller.state.todaySummary.totalDelta, 0);
    } finally {
      await directory.delete(recursive: true);
    }
  });

  test('failed snapshot replace rolls back saved config and snapshots',
      () async {
    final directory = await Directory.systemTemp.createTemp('oj_import_test_');
    try {
      final store = _FailingReplaceStore(supportDirectory: directory);
      await store.saveConfig(_localConfig('old-user'));
      await store.replaceSnapshots([
        _snapshot('2026-06-15', 'old-user', 1),
      ]);
      await store.replaceProblems([_problem(id: 'old-problem')]);
      await store.replaceContests([_contest(id: 'old-contest')]);
      await store.saveRefreshLogs([
        _refreshLog(username: 'old-user'),
      ]);

      final controller = OjController(
        storage: store,
        service: RefreshService(client: http.Client(), providers: const {}),
        startupService: NoopStartupService(),
      );
      await controller.init();

      final importFile =
          File('${directory.path}${Platform.pathSeparator}backup.json');
      await importFile.writeAsString(_backupJson(
        config: _portableConfig('new-user'),
        snapshots: [_snapshotJson('2026-06-16', 'new-user', 7)],
        problems: [_problem(id: 'new-problem').toStorageJson()],
        contests: [_contest(id: 'new-contest').toStorageJson()],
      ));

      store.failNextReplace = true;
      await expectLater(
        controller.importPortableBackup(
          importFile,
          safetyBackupDirectory: directory,
        ),
        throwsA(isA<FetchException>()),
      );

      final loadedConfig = await store.loadConfig();
      final loadedSnapshots = await store.loadSnapshots();
      final loadedProblems = await store.loadProblems();
      final loadedContests = await store.loadContests();
      final loadedRefreshLogs = await store.loadRefreshLogs();

      expect(loadedConfig.accounts['codeforces']!.usernames, ['old-user']);
      expect(loadedSnapshots, hasLength(1));
      expect(loadedSnapshots.single.username, 'old-user');
      expect(loadedProblems.map((item) => item.id), ['old-problem']);
      expect(loadedContests.map((item) => item.id), ['old-contest']);
      expect(loadedRefreshLogs.map((item) => item.username), ['old-user']);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}

Matcher get throwsFormatException => throwsA(isA<FormatException>());

String _backupJson({
  int schemaVersion = 1,
  String app = 'oj_float',
  String exportType = 'portable_backup',
  Map<String, Object?>? config,
  List<Object?> snapshots = const [],
  List<Object?> dailyStats = const [],
  List<Object?>? problems,
  List<Object?>? contests,
}) {
  return jsonEncode({
    'schemaVersion': schemaVersion,
    'app': app,
    'exportType': exportType,
    'exportedAt': '2026-06-16T12:00:00.000',
    'config': config ?? _portableConfig('alice'),
    'snapshots': snapshots,
    if (problems != null) 'problems': problems,
    if (contests != null) 'contests': contests,
    'dailyStats': dailyStats,
  });
}

Map<String, Object?> _portableConfig(String username) {
  return {
    'refreshIntervalMinutes': 30,
    'accounts': [
      {
        'ojId': 'codeforces',
        'enabled': true,
        'usernames': [username],
      },
    ],
  };
}

AppConfig _localConfig(String username) {
  return AppConfig(
    refreshIntervalMinutes: 60,
    accounts: {
      for (final meta in supportedOjs)
        meta.id: meta.id == 'codeforces'
            ? OjAccountConfig(usernames: [username], enabled: false)
            : const OjAccountConfig(usernames: [], enabled: false),
    },
  );
}

Map<String, Object?> _snapshotJson(
  String date,
  String username,
  int solvedCount,
) {
  return _snapshot(date, username, solvedCount).toJson();
}

SolvedSnapshot _snapshot(String date, String username, int solvedCount) {
  return SolvedSnapshot(
    date: date,
    fetchedAt: DateTime.parse('${date}T08:00:00'),
    ojId: 'codeforces',
    username: username,
    status: FetchStatus.success,
    solvedCount: solvedCount,
  );
}

class _FailingReplaceStore extends LocalStore {
  _FailingReplaceStore({required Directory supportDirectory})
      : super(supportDirectory: supportDirectory);

  bool failNextReplace = false;

  @override
  Future<void> replaceSnapshots(List<SolvedSnapshot> snapshots) {
    if (failNextReplace) {
      failNextReplace = false;
      throw const FileSystemException('replace snapshots failed');
    }
    return super.replaceSnapshots(snapshots);
  }
}

RefreshLogEntry _refreshLog({String username = 'alice'}) {
  return RefreshLogEntry.create(
    fetchedAt: DateTime.parse('2026-06-15T08:00:00'),
    ojId: 'codeforces',
    username: username,
    status: RefreshLogStatus.success,
    source: 'primary',
    message: 'ok',
    solvedCount: 1,
  );
}

ProblemRecord _problem({String id = 'lxyz123abc'}) {
  return ProblemRecord.create(
    id: id,
    title: 'CF 1799A',
    url: 'https://codeforces.com/problemset/problem/1799/A',
    platform: ProblemPlatform.cf,
    status: ProblemStatus.AC,
    tags: const ['贪心', '构造'],
    date: '2026-06-21',
    now: DateTime.parse('2026-06-21T12:00:00'),
  );
}

ContestRecord _contest({String id = 'contest-a'}) {
  return ContestRecord.create(
    id: id,
    title: 'Summer Training Day 1',
    date: '2026-07-01',
    rank: 3,
    totalParticipants: 42,
    solvedCount: 5,
    penalty: 712,
    now: DateTime.parse('2026-07-01T12:00:00'),
  );
}
