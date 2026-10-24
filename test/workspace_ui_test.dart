import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oj_float/main.dart';
import 'package:oj_float/ui/app_theme.dart';
import 'package:oj_float/ui/dashboard/first_run_card.dart';
import 'package:oj_float/ui/dashboard/startup_status_page.dart';

void main() {
  Future<void> surface(WidgetTester tester) async {
    tester.view.reset();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1120, 760);
    addTearDown(tester.view.reset);
    if (Platform.environment['OJ_CAPTURE_WORKSPACE'] == '1') {
      await tester.runAsync(() async {
        final icons = await rootBundle.load('fonts/MaterialIcons-Regular.otf');
        await (FontLoader('MaterialIcons')..addFont(Future.value(icons)))
            .load();
        // Pin a complete CJK font in captures: test shells do not resolve the
        // Windows system fallback chain used by the installed application.
        final bytes = await File('C:/Windows/Fonts/msyh.ttc').readAsBytes();
        await (FontLoader(appSystemFontFamily)
              ..addFont(Future.value(ByteData.sublistView(bytes))))
            .load();
      });
    }
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    if (Platform.environment['OJ_CAPTURE_WORKSPACE'] != '1') return;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/workspace-preview/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
      'overview respects saved order and width at desktop and minimum sizes',
      (tester) async {
    await surface(tester);
    final key = GlobalKey();
    final config = AppConfig.defaults().copyWith(
        colorTheme: AppColorTheme.sage,
        appearanceMode: AppAppearanceMode.light,
        dashboardModules: [
          DashboardModule.summary,
          DashboardModule.problems,
          DashboardModule.heatmap,
          DashboardModule.daily
        ],
        dashboardOrder: [
          DashboardModule.summary,
          DashboardModule.problems,
          DashboardModule.heatmap,
          DashboardModule.daily
        ],
        wideDashboardModules: [
          DashboardModule.daily
        ]);
    await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: OjFloatApp(
            initialConfig: config,
            enablePlatformIntegration: false,
            autoInitializeController: false)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dashboard-customization-section')),
        findsNothing);
    final problems = find.byKey(const ValueKey('dashboard-module-problems'));
    final heatmap = find.byKey(const ValueKey('dashboard-module-heatmap'));
    final summary = find.byKey(const ValueKey('dashboard-module-summary'));
    expect(tester.getSize(summary).width,
        greaterThan(tester.getSize(problems).width));
    expect(tester.getTopLeft(problems).dy, tester.getTopLeft(heatmap).dy);
    expect(tester.getTopLeft(problems).dx,
        lessThan(tester.getTopLeft(heatmap).dx));
    await capture(tester, key, 'overview-sage');
    tester.view.physicalSize = const Size(900, 620);
    await tester.pumpAndSettle();
    expect(tester.getSize(problems).width, tester.getSize(summary).width);
    expect(tester.takeException(), isNull);
  });

  testWidgets('todo navigation opens the existing schedule at minimum size',
      (tester) async {
    await surface(tester);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: const OjFloatApp(
            enablePlatformIntegration: false,
            autoInitializeController: false)));
    await tester.pumpAndSettle();
    await capture(tester, key, 'overview-classic');
    tester.view.physicalSize = const Size(900, 620);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dashboard-nav-todos')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('todo-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('training-schedule-tab')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-schedule-tasks-button')),
        findsOneWidget);
    expect(find.text('记录与分析'), findsNothing);
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'todo-minimum');
  });

  testWidgets(
      'settings keeps explicit save for modules, order, width, and appearance',
      (tester) async {
    await surface(tester);
    SettingsPageResult? saved;
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(),
        home: RepaintBoundary(
            key: key,
            child: Scaffold(
                backgroundColor: appSurfaceColor,
                body: SettingsPage(
                    config: AppConfig.defaults(),
                    initialSyncToken: '',
                    onSave: (value) async => saved = value)))));
    final choice = find.byKey(const ValueKey('theme-choice-sage'));
    await tester.tap(choice);
    await tester.pumpAndSettle();
    expect(saved, isNull);
    expect(
        tester
            .widget<DropdownButtonFormField<AppColorTheme>>(
                find.byKey(const ValueKey('color-theme-field')))
            .initialValue,
        AppColorTheme.sage);
    await capture(tester, key, 'settings-appearance');
    final density = find.byKey(const ValueKey('compact-density-switch'));
    await tester.ensureVisible(density);
    await tester.pumpAndSettle();
    await tester.tap(density);
    await tester.pumpAndSettle();
    final section =
        find.byKey(const ValueKey('dashboard-customization-section'));
    await tester.ensureVisible(section);
    await tester.pumpAndSettle();
    await tester.tap(section);
    await tester.pumpAndSettle();
    final switchFinder =
        find.byKey(const ValueKey('dashboard-module-switch-teammates'));
    await tester.ensureVisible(switchFinder);
    await tester.pumpAndSettle();
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    final up = find.byKey(const ValueKey('dashboard-move-up-problems'));
    await tester.ensureVisible(up);
    await tester.pumpAndSettle();
    await tester.tap(up);
    await tester.pumpAndSettle();
    final width = find.byKey(const ValueKey('dashboard-width-problems'));
    await tester.ensureVisible(width);
    await tester.pumpAndSettle();
    await tester.tap(width);
    await tester.pumpAndSettle();
    await tester.tap(find.text('整行').last);
    await tester.pumpAndSettle();
    expect(saved, isNull);
    await capture(tester, key, 'settings-customization');
    final save = find.byKey(const ValueKey('settings-save-button'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(saved!.config.moduleEnabled(DashboardModule.teammates), isFalse);
    expect(saved!.config.compactDensity, isTrue);
    expect(saved!.config.colorTheme, AppColorTheme.sage);
    expect(
        saved!.config.wideDashboardModules, contains(DashboardModule.problems));
    expect(
        saved!.config.dashboardOrder.indexOf(DashboardModule.problems),
        lessThan(
            saved!.config.dashboardOrder.indexOf(DashboardModule.heatmap)));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'problem page creates empty folders, combines tags, and batches selected rows',
      (tester) async {
    await surface(tester);
    final key = GlobalKey();
    var folders = <String>['动态规划', '图论'];
    var problems = [
      _problem('a', '最长递增子序列', ['DP', '二分'], '动态规划'),
      _problem('b', '树上的路径', ['DP', '树'], '动态规划'),
      _problem('c', '最短路', ['图论', '最短路'], '图论'),
    ];
    final theme = buildAppTheme(AppColorTheme.ink, AppAppearanceMode.dark);
    await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: RepaintBoundary(
            key: key,
            child: StatefulBuilder(
                builder: (context, update) => ProblemsPage(
                      problems: problems,
                      folders: folders,
                      showBackButton: false,
                      onBack: () {},
                      onParseLink: (url) async => throw UnimplementedError(),
                      onSave: (p) async => update(() {
                        problems = [
                          for (final old in problems)
                            if (old.id == p.id) p else old
                        ];
                      }),
                      onDelete: (_) async {},
                      onOpenProblem: (_) async {},
                      onCreateFolder: (name) async =>
                          update(() => folders = [...folders, name]),
                      onBatch: (ids, change) async => update(() => problems = [
                            for (final p in problems)
                              ids.contains(p.id)
                                  ? change.apply(p, DateTime(2026, 10, 23))
                                  : p
                          ]),
                    )))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('problem-tag-filter-DP')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('problem-tag-filter-二分')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('problem-tag-match-all')));
    await tester.pumpAndSettle();
    expect(find.text('最长递增子序列'), findsOneWidget);
    expect(find.text('树上的路径'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('clear-tag-filter-chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('problem-select-a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('problem-select-b')));
    await tester.pumpAndSettle();
    await capture(tester, key, 'problems-ink');
    tester.view.physicalSize = const Size(724, 562);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'problems-minimum');
    await tester.tap(find.byTooltip('移动到文件夹'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('folder-name-input')), '待复习');
    await tester.tap(find.widgetWithText(FilledButton, '移动'));
    await tester.pumpAndSettle();
    expect(problems.where((p) => p.folder == '待复习'), hasLength(2));
    expect(problems.singleWhere((p) => p.id == 'c').folder, '图论');
    await tester.tap(find.byKey(const ValueKey('create-problem-folder')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('folder-name-input')), '暑期集训');
    await tester.tap(find.widgetWithText(FilledButton, '创建'));
    await tester.pumpAndSettle();
    expect(folders, contains('暑期集训'));
    expect(find.text('最长递增子序列'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'feature pages retain actions and fit both themes at minimum size',
      (tester) async {
    await surface(tester);
    tester.view.physicalSize = const Size(900, 620);
    for (final mode in [AppAppearanceMode.light, AppAppearanceMode.dark]) {
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: OjFloatApp(
              key: ValueKey(mode),
              initialConfig: AppConfig.defaults().copyWith(
                  colorTheme: AppColorTheme.sage, appearanceMode: mode),
              enablePlatformIntegration: false,
              autoInitializeController: false)));
      await tester.pumpAndSettle();
      for (final section in [
        'contests',
        'teammates',
        'refreshLogs',
        'heatmap',
        'settings'
      ]) {
        final nav = find.byKey(ValueKey('dashboard-nav-$section'));
        await tester.ensureVisible(nav);
        await tester.tap(nav);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$section / $mode');
        await capture(tester, key, '$section-${mode.name}-minimum');
      }
    }
  });

  testWidgets('first-use and recovery actions fit the minimum window',
      (tester) async {
    await surface(tester);
    tester.view.physicalSize = const Size(900, 620);
    final key = GlobalKey();
    Widget app(Widget page) => MaterialApp(
        theme: buildAppTheme(AppColorTheme.sage, AppAppearanceMode.light),
        home: RepaintBoundary(key: key, child: page));
    await tester.pumpWidget(app(Scaffold(
        body: Padding(
            padding: const EdgeInsets.all(24),
            child: FirstRunCard(
                onCreateProblem: () {},
                onConnectAccounts: () {},
                onBrowserHelp: () {},
                onSkip: () {})))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'first-use-minimum');
    await tester.pumpWidget(app(StartupStatusPage(
        error: const FormatException('题库文件未通过完整性校验。'),
        onRetry: () {},
        onRestore: () {},
        onOpenDirectory: () {})));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'recovery-minimum');
  });

  testWidgets(
      'fetch failure keeps last success, reason, and stale state visible',
      (tester) async {
    await surface(tester);
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(AppColorTheme.sage, AppAppearanceMode.light),
        home: RepaintBoundary(
            key: key,
            child: Scaffold(
                body: Center(
                    child: SizedBox(
                        width: 420,
                        child: OjTile(
                            meta: supportedOjs.first,
                            config: const OjAccountConfig(
                                usernames: ['alice'], enabled: true),
                            results: [
                              FetchResult.failure(
                                  ojId: 'codeforces',
                                  username: 'alice',
                                  error: '请求超时，请稍后重试',
                                  fetchedAt: DateTime(2026, 10, 24, 12),
                                  solvedCount: 0,
                                  previousSolvedCount: 42)
                            ],
                            today: 0,
                            accountActivity: const {},
                            snapshots: [
                              SolvedSnapshot(
                                  date: '2026-10-23',
                                  fetchedAt: DateTime(2026, 10, 23, 12),
                                  ojId: 'codeforces',
                                  username: 'alice',
                                  status: FetchStatus.success,
                                  solvedCount: 42)
                            ])))))));
    await tester.pumpAndSettle();
    expect(find.text('42 (保留)'), findsOneWidget);
    expect(find.text('请求超时，请稍后重试'), findsOneWidget);
    expect(
        find.textContaining('上次成功 2026-10-23 12:00 · 数据待更新'), findsOneWidget);
    expect(find.text('本次失败 2026-10-24 12:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'fetch-failure');
  });
}

ProblemRecord _problem(
        String id, String title, List<String> tags, String folder) =>
    ProblemRecord.create(
        id: id,
        title: title,
        url: 'https://example.test/$id',
        platform: ProblemPlatform.other,
        tags: tags,
        folder: folder,
        date: '2026-10-23',
        note: '保留思路、题解和原有训练记录',
        now: DateTime(2026, 10, 23));
