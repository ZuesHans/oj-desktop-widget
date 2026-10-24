import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oj_float/main.dart';
import 'package:oj_float/models/problem_batch.dart';
import 'package:oj_float/services/module_http_client.dart';
import 'package:oj_float/ui/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import 'test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('workspace configuration and portable settings survive round trip', () {
    final config = AppConfig.defaults().copyWith(
      dashboardModules: const [
        DashboardModule.problems,
        DashboardModule.summary
      ],
      dashboardOrder: const [
        DashboardModule.problems,
        DashboardModule.summary,
        DashboardModule.daily,
        DashboardModule.training,
        DashboardModule.heatmap,
        DashboardModule.contests,
        DashboardModule.refreshLogs,
        DashboardModule.teammates,
        DashboardModule.ojAccounts
      ],
      wideDashboardModules: const [DashboardModule.problems],
      colorTheme: AppColorTheme.sage,
      appearanceMode: AppAppearanceMode.dark,
      compactDensity: true,
    );
    for (final json in [config.toJson(), buildPortableConfigJson(config)]) {
      final restored = AppConfig.fromJson(Map<String, dynamic>.from(json));
      expect(restored.dashboardModules, config.dashboardModules);
      expect(restored.dashboardOrder, config.dashboardOrder);
      expect(restored.wideDashboardModules, config.wideDashboardModules);
      expect(restored.appearanceMode, AppAppearanceMode.dark);
      expect(restored.compactDensity, isTrue);
      expect(restored.colorTheme, AppColorTheme.sage);
    }
    final repaired = AppConfig.fromJson({
      'configVersion': 4,
      'dashboardModules': [],
      'dashboardOrder': ['problems', 'problems', 'unknown'],
    });
    expect(repaired.dashboardModules, isEmpty);
    expect(repaired.dashboardOrder.first, DashboardModule.problems);
    expect(repaired.dashboardOrder.toSet(), DashboardModule.values.toSet());
    expect(AppConfig.fromJson({'configVersion': 3}).dashboardOrder,
        defaultDashboardModules);
  });

  test('folders migrate from v3, persist empty, and notify the other client',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('workspace_folders_');
    try {
      final store = LocalStore(supportDirectory: directory);
      await store.saveProblem(_problem('p').copyWith(folder: 'DP'));
      final path = '${directory.path}/$problemDatabaseFileName';
      final raw = sqlite3.open(path);
      raw.execute('DROP TRIGGER problems_folder_after_insert');
      raw.execute('DROP TRIGGER problems_folder_after_update');
      raw.execute('DROP TABLE problem_folders');
      raw.execute('PRAGMA user_version = 3');
      raw.close();
      final other = LocalStore(supportDirectory: directory);
      final before = await other.loadProblemSnapshot();
      expect(before.folders, ['DP']);
      await store.createProblemFolder('  Empty  ');
      await store.createProblemFolder('empty');
      final after = await other.loadProblemSnapshot();
      expect(after.folders, ['DP', 'Empty']);
      expect(after.revision, before.revision + 1);
      await other
          .saveProblem(_problem('p').copyWith(folder: 'dp', note: 'keep'));
      await other.replaceProblems([]);
      expect((await store.loadProblemSnapshot()).folders, ['DP', 'Empty']);
    } finally {
      await deleteTestDirectory(directory);
    }
  });

  test('batch changes preserve concurrent fields and roll back on failure',
      () async {
    final directory = await Directory.systemTemp.createTemp('workspace_batch_');
    try {
      final store = LocalStore(supportDirectory: directory);
      await store
          .saveProblems([_problem('a'), _problem('b'), _problem('untouched')]);
      final other = LocalStore(supportDirectory: directory);
      await other.saveProblem(_problem('a')
          .copyWith(note: 'external', analysis: 'retained', isFavorite: true));
      await store.applyProblemBatch({'a', 'b'},
          const ProblemBatchChange(folder: 'DP', addTags: ['graph', 'DP']));
      await store.applyProblemBatch(
          {'a'},
          const ProblemBatchChange(
              removeTags: ['dp'], status: ProblemWorkflowStatus.archived));
      final rows = await other.loadProblems();
      final a = rows.singleWhere((p) => p.id == 'a');
      expect(a.note, 'external');
      expect(a.analysis, 'retained');
      expect(a.isFavorite, isTrue);
      expect(a.tags, ['graph']);
      expect(a.archivedAt, isNotNull);
      expect(rows.singleWhere((p) => p.id == 'untouched').folder, isEmpty);
      await store.applyProblemBatch({'a'},
          const ProblemBatchChange(status: ProblemWorkflowStatus.backlog));
      expect(
          (await store.loadProblems())
              .singleWhere((p) => p.id == 'a')
              .archivedAt,
          isNull);
      final database =
          sqlite3.open('${directory.path}/$problemDatabaseFileName');
      database.execute(
          "CREATE TRIGGER reject_batch BEFORE UPDATE ON problems WHEN NEW.folder = 'reject' AND NEW.id = 'b' BEGIN SELECT RAISE(ABORT, 'test'); END;");
      database.close();
      await expectLater(
          store.applyProblemBatch(
              {'a', 'b'}, const ProblemBatchChange(folder: 'reject')),
          throwsA(isA<SqliteException>()));
      expect((await other.loadProblems()).any((p) => p.folder == 'reject'),
          isFalse);
    } finally {
      await deleteTestDirectory(directory);
    }
  });

  test('folder and multi-tag filters combine with platform and search', () {
    final rows = [
      _problem('a').copyWith(folder: 'DP', tags: ['Graph', 'DP']),
      _problem('b').copyWith(folder: 'DP', tags: ['graph']),
      _problem('c').copyWith(tags: ['DP']),
    ];
    expect(
        filterProblems(rows,
                folder: 'dp', tags: {'graph', 'dp'}, matchAllTags: true)
            .map((p) => p.id),
        ['a']);
    expect(filterProblems(rows, folder: 'dp', tags: {'graph', 'dp'}),
        hasLength(2));
    expect(filterProblems(rows, folder: '').single.id, 'c');
    expect(filterProblems(rows, folder: 'DP', tags: {'dp'}, query: 'missing'),
        isEmpty);
  });

  test('empty folders round trip through portable and automatic backups',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('workspace_backup_');
    final controller =
        _controller(LocalStore(supportDirectory: directory), _Provider());
    try {
      await controller.init();
      await controller.createProblemFolder('Empty');
      final portable = buildPortableBackupJson(
          config: controller.state.config,
          snapshots: const [],
          problemFolders: controller.state.problemFolders,
          exportedAt: DateTime(2026, 10, 23));
      final old = jsonDecode(portable) as Map<String, dynamic>;
      old.remove('problemFolders');
      expect(parsePortableBackupJson(jsonEncode(old)).problemFolders, isEmpty);
      final file = File('${directory.path}/portable.json');
      await file.writeAsString(portable);
      await controller.createProblemFolder('Extra');
      await controller.importPortableBackup(file,
          safetyBackupDirectory: Directory('${directory.path}/safety'));
      expect(controller.state.problemFolders, ['Empty']);
      final service = AutomaticBackupService(
          defaultDirectoryProvider: () async =>
              Directory('${directory.path}/auto'));
      final created = await service.createBackup(
          config: const AutomaticBackupConfig(enabled: true),
          problems: const [],
          problemFolders: ['Empty'],
          training: controller.state.training,
          contests: const []);
      final parsed = parseCoreTrainingBackupJson(
          await File(created.filePath!).readAsString());
      expect(parsed.problemFolders, ['Empty']);
      await controller.createProblemFolder('Extra');
      await controller.importPortableBackup(File(created.filePath!),
          safetyBackupDirectory: Directory('${directory.path}/safety'));
      expect(controller.state.problemFolders, ['Empty']);
      await controller.saveProblem(_problem('active'));
      await controller.startTraining('active');
      await file.writeAsString(buildPortableBackupJson(
          config: controller.state.config
              .copyWith(dashboardModules: [DashboardModule.problems]),
          snapshots: const [],
          problems: controller.state.problems,
          problemFolders: controller.state.problemFolders,
          training: controller.state.training,
          exportedAt: DateTime(2026, 10, 23)));
      await controller.importPortableBackup(file,
          safetyBackupDirectory: Directory('${directory.path}/safety'));
      expect(controller.state.training.activeAttempt!.isPaused, isTrue);
    } finally {
      controller.dispose();
      await deleteTestDirectory(directory);
    }
  });

  test('module client cancels in flight, rejects disabled sends, and reopens',
      () async {
    final response = Completer<http.Response>();
    var calls = 0;
    final client = ModuleHttpClient(MockClient((request) {
      calls++;
      return calls == 1
          ? response.future
          : Future.value(http.Response('ok', 200));
    }));
    final request = client.get(Uri.parse('https://example.test/'));
    final cancelled =
        expectLater(request, throwsA(isA<http.RequestAbortedException>()));
    await Future<void>.delayed(Duration.zero);
    client.setEnabled(false);
    await cancelled;
    await expectLater(client.get(Uri.parse('https://example.test/')),
        throwsA(isA<http.RequestAbortedException>()));
    expect(calls, 1);
    response.complete(http.Response('old', 200));
    client.setEnabled(true);
    expect((await client.get(Uri.parse('https://example.test/'))).body, 'ok');
    client.close();
  });

  test(
      'disabled startup skips fetching, discards late results, and retains data',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('workspace_modules_');
    final provider = _Provider();
    final store = LocalStore(supportDirectory: directory);
    final controller = _controller(store, provider);
    try {
      final config = AppConfig.defaults().copyWith(dashboardModules: [
        DashboardModule.problems
      ], accounts: {
        'codeforces': const OjAccountConfig(usernames: ['alice'], enabled: true)
      });
      await store.saveConfig(config);
      await store.saveTeammates(TeammateStoreData(profiles: [
        TeammateProfile.create(id: 'friend', nickname: 'Friend', accounts: [
          const TeammateAccount(platform: 'codeforces', handle: 'friend')
        ])
      ]));
      await store.saveProblem(_problem('keep'));
      await controller.init();
      await controller.refresh();
      await controller.refreshAllTeammates();
      expect(provider.calls, 0);
      expect(controller.state.problems.single.id, 'keep');
      final enabled =
          config.copyWith(dashboardModules: defaultDashboardModules);
      await controller.saveConfig(enabled);
      provider.pending = Completer<OjProfile>();
      final refresh = controller.refresh();
      await Future<void>.delayed(Duration.zero);
      await controller.saveConfig(config);
      provider.pending!.complete(const OjProfile(
          solvedCount: 10, profileUrl: 'https://example.test/'));
      await refresh;
      expect(controller.state.latest, isEmpty);
      expect(controller.state.snapshots, isEmpty);
      provider.pending = null;
      await controller.saveConfig(enabled);
      await controller.refresh();
      expect(controller.state.snapshots.single.solvedCount, 10);
      provider.pending = Completer<OjProfile>();
      final teammateRefresh = controller.refreshAllTeammates();
      await Future<void>.delayed(Duration.zero);
      await controller.saveConfig(config);
      provider.pending!.complete(const OjProfile(
          solvedCount: 10, profileUrl: 'https://example.test/'));
      await teammateRefresh;
      expect(controller.state.teammates.snapshots, isEmpty);
      expect(controller.state.teammates.profiles, hasLength(1));
      provider.pending = null;
      await controller.saveConfig(enabled);
      await controller.refreshAllTeammates();
      expect(controller.state.teammates.snapshots, isNotEmpty);
      await controller.startTraining('keep');
      await controller.saveConfig(config);
      expect(controller.state.training.activeAttempt!.isPaused, isTrue);
      expect(controller.state.problems.single.id, 'keep');
    } finally {
      controller.dispose();
      await deleteTestDirectory(directory);
    }
  });

  testWidgets(
      'only enabled navigation remains and customization stays in settings',
      (tester) async {
    final config = AppConfig.defaults().copyWith(dashboardModules: [
      DashboardModule.summary,
      DashboardModule.problems
    ], dashboardOrder: [
      DashboardModule.problems,
      ...defaultDashboardModules.where((m) => m != DashboardModule.problems)
    ]);
    await tester.pumpWidget(OjFloatApp(
        initialConfig: config,
        enablePlatformIntegration: false,
        autoInitializeController: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dashboard-nav-training')), findsNothing);
    expect(find.byKey(const ValueKey('dashboard-nav-todos')), findsNothing);
    expect(find.byTooltip('快速录入 (Ctrl+Shift+O)'), findsOneWidget);
    expect(find.byKey(const ValueKey('dashboard-customization-section')),
        findsNothing);
    expect(find.byKey(const ValueKey('home-action-teammates')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('dashboard-nav-settings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dashboard-customization-section')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('color-theme-field')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all disabled leaves settings accessible without quick entry',
      (tester) async {
    await tester.pumpWidget(OjFloatApp(
        initialConfig: AppConfig.defaults().copyWith(dashboardModules: []),
        enablePlatformIntegration: false,
        autoInitializeController: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dashboard-section-settings')),
        findsOneWidget);
    expect(find.byTooltip('快速录入 (Ctrl+Shift+O)'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('theme modes honor explicit brightness and retain original palettes',
      () {
    for (final theme in AppColorTheme.values) {
      expect(buildAppTheme(theme, AppAppearanceMode.dark).brightness,
          Brightness.dark);
      expect(buildAppTheme(theme, AppAppearanceMode.light).brightness,
          Brightness.light);
    }
    expect(
        buildAppTheme(AppColorTheme.sage, AppAppearanceMode.system,
                Brightness.dark, true)
            .visualDensity,
        VisualDensity.compact);
    expect(buildAppTheme().brightness, Brightness.light);
  });
}

ProblemRecord _problem(String id) => ProblemRecord.create(
    id: id,
    title: id,
    url: 'https://example.test/$id',
    platform: ProblemPlatform.other,
    date: '2026-10-23',
    now: DateTime(2026, 10, 23));

OjController _controller(LocalStore store, _Provider provider) => OjController(
    storage: store,
    service: RefreshService(
        client: http.Client(), providers: {'codeforces': provider}),
    startupService: NoopStartupService());

class _Provider implements OjProvider {
  int calls = 0;
  Completer<OjProfile>? pending;
  @override
  Future<OjProfile> fetchProfile(http.Client client, String username) {
    calls++;
    return pending?.future ??
        Future.value(const OjProfile(
            solvedCount: 10, profileUrl: 'https://example.test/'));
  }
}
