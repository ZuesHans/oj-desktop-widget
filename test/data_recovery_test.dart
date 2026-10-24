import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oj_float/main.dart';
import 'package:oj_float/services/data_recovery_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('file preferences preserve old keys and recover a damaged primary',
      () async {
    final directory = await Directory.systemTemp.createTemp('file_prefs_');
    addTearDown(() => deleteTestDirectory(directory));
    final file = File('${directory.path}/shared_preferences.json');
    await file.writeAsString(jsonEncode({
      'flutter.app_config_v1': jsonEncode(
          AppConfig.defaults().copyWith(refreshIntervalMinutes: 37).toJson()),
      'flutter.first_saved_problem': true,
    }));
    final store =
        LocalStore(supportDirectory: directory, useFilePreferences: true);
    final config = await store.loadConfig();
    expect(config.refreshIntervalMinutes, 37);
    await store.saveConfig(config.copyWith(refreshIntervalMinutes: 41));
    expect(jsonDecode(await file.readAsString())['flutter.first_saved_problem'],
        isTrue);
    await file.writeAsString('{broken');
    expect((await store.loadConfig()).refreshIntervalMinutes, 37);
    await file.writeAsString('{broken');
    await File('${file.path}.bak').writeAsString('{also-broken');
    await expectLater(store.loadConfig(), throwsFormatException);
    expect(await file.readAsString(), '{broken');
  });

  test('a failed legacy migration can be retried on the same store', () async {
    final directory = await Directory.systemTemp.createTemp('migration_retry_');
    addTearDown(() => deleteTestDirectory(directory));
    final file = File('${directory.path}/problems_v1.json');
    await file.writeAsString('{broken');
    final store = LocalStore(supportDirectory: directory);
    await expectLater(store.loadProblemSnapshot(), throwsFormatException);
    final db = sqlite3.open('${directory.path}/$problemDatabaseFileName');
    expect(db.select('PRAGMA user_version').single['user_version'],
        ProblemDatabase.schemaVersion);
    expect(
        db.select("SELECT * FROM metadata WHERE key = 'legacy_json_migrated'"),
        isEmpty);
    db.close();
    final problem = _problem();
    await file.writeAsString(jsonEncode([problem.toJson()]));
    expect((await store.loadProblems()).single.title, problem.title);
    expect(await file.readAsString(), jsonEncode([problem.toJson()]));
  });

  test('recovery retains corrupt files and secrets before publishing a backup',
      () async {
    final root = await Directory.systemTemp.createTemp('recover_data_');
    addTearDown(() => deleteTestDirectory(root));
    final directory = await Directory('${root.path}/data').create();
    final original = <String, List<int>>{
      problemDatabaseFileName: [1, 2, 3, 4],
      '$problemDatabaseFileName-wal': [5, 6, 7],
      'training_v1.json': utf8.encode('{damaged-training'),
      'shared_preferences.json': utf8.encode('{damaged-prefs'),
      'flutter_secure_storage.dat': [31, 58, 89, 245, 0, 16],
      'unrecognized-file.bin': [99, 101],
    };
    for (final entry in original.entries) {
      await File('${directory.path}/${entry.key}').writeAsBytes(entry.value);
    }
    final backup = await _backup(root);
    final retained = await DataRecoveryService().restore(backup, directory);
    for (final entry in original.entries) {
      expect(await File('${retained.path}/${entry.key}').readAsBytes(),
          entry.value,
          reason: entry.key);
    }
    final store =
        LocalStore(supportDirectory: directory, useFilePreferences: true);
    expect((await store.loadConfig()).refreshIntervalMinutes, 43);
    final snapshot = await store.loadCoreBackupSnapshot();
    expect(snapshot.problems.single.note, '保留题解与训练记录');
    expect(snapshot.problemFolders, contains('空文件夹'));
    for (final name in [
      'flutter_secure_storage.dat',
      'unrecognized-file.bin'
    ]) {
      expect(
          await File('${directory.path}/$name').readAsBytes(), original[name]);
    }
  });

  test('invalid backup and an occupied data directory leave originals intact',
      () async {
    final root = await Directory.systemTemp.createTemp('recover_reject_');
    addTearDown(() => deleteTestDirectory(root));
    final directory = await Directory('${root.path}/data').create();
    final store = LocalStore(supportDirectory: directory);
    await store.saveProblem(_problem());
    final invalid = File('${root.path}/invalid.json');
    await invalid.writeAsString('{}');
    await expectLater(DataRecoveryService().restore(invalid, directory),
        throwsFormatException);
    expect((await store.loadProblems()).single.title, _problem().title);
    if (Platform.isWindows) {
      final locked = sqlite3.open('${directory.path}/$problemDatabaseFileName');
      try {
        final backup = await _backup(root);
        await expectLater(DataRecoveryService().restore(backup, directory),
            throwsA(isA<FileSystemException>()));
        expect((await store.loadProblems()).single.title, _problem().title);
      } finally {
        locked.close();
      }
      expect(
          await root.list().where((f) => f.path.contains('.restoring-')).length,
          0);
    }
  });

  testWidgets('startup blocks an empty workspace and supports repair and retry',
      (tester) async {
    final directory = Directory.systemTemp.createTempSync('startup_repair_');
    addTearDown(() => deleteTestDirectory(directory));
    final file = File('${directory.path}/problems_v1.json');
    file.writeAsStringSync('{broken');
    await tester.pumpWidget(MaterialApp(
      home: OjFloatHome(
        enablePlatformIntegration: false,
        storage: LocalStore(supportDirectory: directory),
      ),
    ));
    await tester.runAsync(() async {
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        if (find
            .byKey(const ValueKey('startup-recovery'))
            .evaluate()
            .isNotEmpty) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('startup-recovery')), findsOneWidget);
    expect(find.byKey(const ValueKey('dashboard-shell')), findsNothing);
    expect(find.byKey(const ValueKey('toolbar-refresh-button')), findsNothing);
    file.writeAsStringSync(jsonEncode([_problem().toJson()]));
    await tester.tap(find.byKey(const ValueKey('startup-retry')));
    await tester.runAsync(() async {
      for (var i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        if (find
                .byKey(const ValueKey('dashboard-shell'))
                .evaluate()
                .isNotEmpty &&
            find.byType(CircularProgressIndicator).evaluate().isEmpty) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dashboard-shell')), findsOneWidget);
    expect(find.byKey(const ValueKey('startup-recovery')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('dashboard-nav-problems')));
    await tester.pumpAndSettle();
    expect(find.text(_problem().title), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('loading waits for local records before exposing actions',
      (tester) async {
    final directory = Directory.systemTemp.createTempSync('startup_wait_');
    addTearDown(() => deleteTestDirectory(directory));
    final gate = Completer<void>();
    final store = _GatedStore(directory, gate);
    await tester.pumpWidget(MaterialApp(
        home: OjFloatHome(enablePlatformIntegration: false, storage: store)));
    await tester.pump();
    expect(find.byKey(const ValueKey('startup-loading')), findsOneWidget);
    expect(find.byKey(const ValueKey('dashboard-shell')), findsNothing);
    // Dispose before releasing to also exercise closing during disk loading.
    await tester.pumpWidget(const SizedBox());
    gate.complete();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a new user saves a first problem without configuring accounts',
      (tester) async {
    tester.view.physicalSize = const Size(1120, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final directory = Directory.systemTemp.createTempSync('first_use_');
    addTearDown(() => deleteTestDirectory(directory));
    final store =
        LocalStore(supportDirectory: directory, useFilePreferences: true);
    await tester.pumpWidget(MaterialApp(
        home: OjFloatHome(enablePlatformIntegration: false, storage: store)));
    await _waitForStartup(tester);
    final create = find.byKey(const ValueKey('first-run-create-problem'));
    expect(create, findsOneWidget);
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('problem-url-field')),
        'https://codeforces.com/problemset/problem/1799/A');
    await tester.enterText(
        find.byKey(const ValueKey('problem-title-field')), '我的第一道题');
    await tester.tap(find.byKey(const ValueKey('save-problem-button')));
    await _waitFor(
        tester,
        () =>
            find.byKey(const ValueKey('problems-page')).evaluate().isNotEmpty);
    expect(find.text('我的第一道题'), findsOneWidget);
    await tester.runAsync(() async {
      expect((await store.loadProblems()).single.title, '我的第一道题');
      final saved = await store.loadConfig();
      expect(saved.onboardingComplete, isTrue);
      expect(saved.accounts.values.every((a) => !a.enabled), isTrue);
    });
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('first use can be skipped and stays dismissed after reopening',
      (tester) async {
    tester.view.physicalSize = const Size(1120, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final directory = Directory.systemTemp.createTempSync('first_use_skip_');
    addTearDown(() => deleteTestDirectory(directory));
    final store =
        LocalStore(supportDirectory: directory, useFilePreferences: true);
    Widget app() => MaterialApp(
        home: OjFloatHome(enablePlatformIntegration: false, storage: store));
    await tester.pumpWidget(app());
    await _waitForStartup(tester);
    final skip = find.byKey(const ValueKey('skip-first-run'));
    await tester.ensureVisible(skip);
    await tester.tap(skip);
    await _waitFor(tester,
        () => find.byKey(const ValueKey('first-run-guide')).evaluate().isEmpty);
    expect(find.byKey(const ValueKey('first-run-guide')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await _waitForStartup(tester);
    expect(find.byKey(const ValueKey('first-run-guide')), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}

Future<void> _waitForStartup(WidgetTester tester) async {
  await _waitFor(
      tester,
      () =>
          find.byKey(const ValueKey('dashboard-shell')).evaluate().isNotEmpty &&
          find.byType(CircularProgressIndicator).evaluate().isEmpty);
}

Future<void> _waitFor(WidgetTester tester, bool Function() done) async {
  await tester.runAsync(() async {
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (done()) break;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  });
  await tester.pumpAndSettle();
}

class _GatedStore extends LocalStore {
  _GatedStore(Directory directory, this.gate)
      : super(supportDirectory: directory);
  final Completer<void> gate;

  @override
  Future<CoreStoreSnapshot> loadCoreBackupSnapshot() async {
    await gate.future;
    throw const FormatException('test loading stopped');
  }
}

ProblemRecord _problem() => ProblemRecord.create(
    id: 'retained',
    title: '迁移后的题目',
    url: 'https://example.test/problem',
    platform: ProblemPlatform.other,
    tags: const ['DP'],
    folder: '动态规划',
    date: '2026-10-24',
    note: '保留题解与训练记录',
    now: DateTime(2026, 10, 24));

Future<File> _backup(Directory root) async {
  final result = await exportOjData(
      config: AppConfig.defaults().copyWith(refreshIntervalMinutes: 43),
      snapshots: [],
      problems: [_problem()],
      problemFolders: ['空文件夹'],
      directory: Directory('${root.path}/backups'),
      writeDailySummary: false);
  return result.backupFile;
}
