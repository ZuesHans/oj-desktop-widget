import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oj_float/main.dart';
import 'package:oj_float/services/app_data_directory.dart';
import 'package:sqlite3/sqlite3.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('v0.1.3 JSON and settings migrate once without modifying legacy files',
      () async {
    final root = await Directory.systemTemp.createTemp('identity_legacy_');
    addTearDown(() => deleteTestDirectory(root));
    final legacy = await Directory('${root.path}/com.example/oj_float')
        .create(recursive: true);
    final target = Directory('${root.path}/ZuesHans/OJ Float');
    // Shape produced by main (v0.1.3), including JSON encoded tags and WA.
    final files = <String, List<int>>{
      'shared_preferences.json': utf8.encode(jsonEncode({
        'flutter.app_config_v1': jsonEncode({
          'refreshIntervalMinutes': 45,
          'colorTheme': 'classic',
          'closeToTray': true,
          'launchAtStartup': false,
          'dashboardModules': ['heatmap', 'problems', 'contests'],
          'accounts': {
            'codeforces': {'username': 'legacy-user', 'enabled': true}
          },
          'sync': {'enabled': false, 'includeProblemAnalysis': true}
        }),
        'flutter.other_preference': true,
      })),
      'problems_v1.json': utf8.encode(jsonEncode([
        {
          'id': 'v013-problem',
          'title': 'Recent Actions',
          'url': 'https://codeforces.com/problemset/problem/1799/A',
          'platform': 'cf',
          'status': 'WA',
          'tags': '["implementation","模拟"]',
          'date': '2026-09-01',
          'note': '旧版笔记',
          'analysis': '旧版题解',
          'created_at': '2026-09-01T10:30:00.000',
          'updated_at': '2026-09-02T11:30:00.000',
        }
      ])),
      'snapshots_v1.json': utf8.encode(jsonEncode([
        {
          'date': '2026-09-01',
          'fetchedAt': '2026-09-01T10:30:00.000',
          'ojId': 'codeforces',
          'username': 'legacy-user',
          'status': 'success',
          'solvedCount': 123,
          'error': null
        }
      ])),
      'flutter_secure_storage.dat': [3, 0, 255, 100, 19, 47],
    };
    for (final entry in files.entries) {
      await File('${legacy.path}/${entry.key}').writeAsBytes(entry.value);
    }
    await AppDataMigration().migrate(legacy: legacy, destination: target);
    final store =
        LocalStore(supportDirectory: target, useFilePreferences: true);
    final config = await store.loadConfig();
    expect(config.accounts['codeforces']!.usernames, ['legacy-user']);
    expect(config.refreshIntervalMinutes, 45);
    expect(config.sync.includeProblemAnalysis, isTrue);
    final core = await store.loadCoreBackupSnapshot();
    expect(core.problems.single.id, 'v013-problem');
    expect(core.problems.single.tags, ['implementation', '模拟']);
    expect(core.problems.single.note, '旧版笔记');
    expect(core.problems.single.analysis, '旧版题解');
    expect(core.training.attempts, isEmpty);
    expect((await store.loadSnapshots()).single.solvedCount, 123);
    expect(
        await File('${target.path}/flutter_secure_storage.dat').readAsBytes(),
        files['flutter_secure_storage.dat']);
    await store.saveProblem(core.problems.single.copyWith(note: '新版修改'));
    await AppDataMigration().migrate(legacy: legacy, destination: target);
    expect((await store.loadProblems()).single.note, '新版修改');
    for (final entry in files.entries) {
      expect(
          await File('${legacy.path}/${entry.key}').readAsBytes(), entry.value);
    }
  });

  test('SQLite migration includes committed WAL rows and empty folders',
      () async {
    final root = await Directory.systemTemp.createTemp('identity_wal_');
    addTearDown(() => deleteTestDirectory(root));
    final legacy = await Directory('${root.path}/legacy').create();
    final target = Directory('${root.path}/stable');
    final source =
        LocalStore(supportDirectory: legacy, useFilePreferences: true);
    await source.saveConfig(AppConfig.defaults());
    await source.saveProblem(_problem());
    await source.createProblemFolder('空文件夹');
    final database = sqlite3.open('${legacy.path}/$problemDatabaseFileName');
    try {
      database.execute('PRAGMA journal_mode = WAL');
      database.execute('PRAGMA wal_autocheckpoint = 0');
      database.execute(
          "UPDATE problems SET note = 'wal note' WHERE id = 'existing'");
      expect(await File('${legacy.path}/$problemDatabaseFileName-wal').length(),
          greaterThan(0));
      await AppDataMigration().migrate(legacy: legacy, destination: target);
      final snapshot =
          await LocalStore(supportDirectory: target).loadProblemSnapshot();
      expect(snapshot.problems.single.note, 'wal note');
      expect(snapshot.folders, contains('空文件夹'));
      expect(database.select('SELECT note FROM problems').single['note'],
          'wal note');
    } finally {
      database.close();
    }
  });

  test('failed migration leaves destination unpublished and can be retried',
      () async {
    final root = await Directory.systemTemp.createTemp('identity_retry_');
    addTearDown(() => deleteTestDirectory(root));
    final legacy = await Directory('${root.path}/legacy').create();
    final target = await Directory('${root.path}/stable').create();
    final damaged = File('${legacy.path}/problems_v1.json');
    await damaged.writeAsString('{damaged');
    final migration = AppDataMigration();
    await expectLater(migration.migrate(legacy: legacy, destination: target),
        throwsFormatException);
    expect(await target.list().isEmpty, isTrue);
    expect(await damaged.readAsString(), '{damaged');
    await damaged.writeAsString(jsonEncode([_problem().toStorageJson()]));
    await migration.migrate(legacy: legacy, destination: target);
    expect(
        (await LocalStore(supportDirectory: target).loadProblems()).single.id,
        'existing');
    expect(
        await root.list().where((f) => f.path.contains('.migrating-')).length,
        0);
  });

  test('conflicting stores and a running older client never merge silently',
      () async {
    final root = await Directory.systemTemp.createTemp('identity_conflict_');
    addTearDown(() => deleteTestDirectory(root));
    final legacy = await Directory('${root.path}/legacy').create();
    final target = await Directory('${root.path}/stable').create();
    await File('${legacy.path}/problems_v1.json').writeAsString('[]');
    final newer = File('${target.path}/newer.txt');
    await newer.writeAsString('keep');
    await expectLater(
        AppDataMigration().migrate(legacy: legacy, destination: target),
        throwsA(isA<FileSystemException>()));
    expect(await newer.readAsString(), 'keep');
    await newer.delete();
    await expectLater(
        AppDataMigration(beforeCopy: () async {
          throw const FileSystemException('older client is running');
        }).migrate(legacy: legacy, destination: target),
        throwsA(isA<FileSystemException>()));
    expect(await target.list().isEmpty, isTrue);
  });
}

ProblemRecord _problem() => ProblemRecord.create(
    id: 'existing',
    title: 'Existing',
    url: 'https://example.test/problem',
    platform: ProblemPlatform.other,
    tags: const [],
    date: '2026-10-24',
    note: 'note',
    now: DateTime(2026, 10, 24));
