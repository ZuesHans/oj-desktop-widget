import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oj_float/main.dart';
import 'package:oj_float/ui/app_labels.dart';

void main() {
  Widget buildTestApp() {
    return const OjFloatApp(
      enablePlatformIntegration: false,
      autoInitializeController: false,
    );
  }

  Future<void> openDashboardShell(WidgetTester tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();
  }

  Future<void> tapDashboardNav(
    WidgetTester tester,
    String sectionName,
  ) async {
    await tester.tap(find.byKey(ValueKey('dashboard-nav-$sectionName')));
    await tester.pumpAndSettle();
  }

  void expectDashboardNavKeys() {
    for (final sectionName in [
      'summary',
      'heatmap',
      'problems',
      'refreshLogs',
      'contests',
      'teammates',
      'ojAccounts',
      'daily',
      'settings',
    ]) {
      expect(
          find.byKey(ValueKey('dashboard-nav-$sectionName')), findsOneWidget);
    }
  }

  testWidgets('app starts directly in the desktop dashboard', (tester) async {
    await openDashboardShell(tester);

    expect(find.byKey(const ValueKey('dashboard-shell')), findsOneWidget);
    expect(find.byKey(const ValueKey('dashboard-nav')), findsOneWidget);
    expect(find.byKey(const ValueKey('app-toolbar')), findsOneWidget);
    expect(find.byKey(const ValueKey('app-brand-icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-summary-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('compact-widget')), findsNothing);
    expect(find.byKey(const ValueKey('compact-mode-button')), findsNothing);
    expect(find.text('今日训练'), findsWidgets);
  });

  testWidgets('desktop dashboard navigates to feature and settings pages',
      (tester) async {
    await openDashboardShell(tester);

    await tester.tap(find.byKey(const ValueKey('dashboard-nav-problems')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('problems-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('problems-back-button')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('dashboard-nav-settings')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dashboard-section-settings')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('settings-save-button')), findsOneWidget);
  });

  testWidgets('dashboard shell exposes nav keys and summary home panel',
      (tester) async {
    await openDashboardShell(tester);

    expect(find.byKey(const ValueKey('dashboard-shell')), findsOneWidget);
    expect(find.byKey(const ValueKey('dashboard-nav')), findsOneWidget);
    expectDashboardNavKeys();
    expect(find.byKey(const ValueKey('dashboard-section-summary')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('home-summary-panel')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-empty-account-state')),
      findsOneWidget,
    );
    expect(find.text('今日训练'), findsWidgets);
  });

  testWidgets('settings exposes client lifecycle controls', (tester) async {
    await openDashboardShell(tester);
    await tapDashboardNav(tester, 'settings');

    expect(
      find.byKey(const ValueKey('dashboard-section-settings')),
      findsOneWidget,
    );
    expect(find.text('登录时启动'), findsOneWidget);
    expect(find.text('关闭窗口时留在托盘'), findsOneWidget);
    expect(find.text('窗口置顶'), findsNothing);
    expect(find.text('在任务栏显示'), findsNothing);
    expect(find.byKey(const ValueKey('settings-save-button')), findsOneWidget);
    final startupSwitch = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('launch-at-startup-switch')),
    );
    expect(startupSwitch.onChanged, isNull);
  });

  testWidgets('backup settings and import dialog fit the minimum client size',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 620));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await openDashboardShell(tester);
    await tapDashboardNav(tester, 'settings');

    final backupSwitch = find.byKey(const ValueKey('automatic-backup-switch'));
    await tester.ensureVisible(backupSwitch);
    await tester.pumpAndSettle();
    expect(backupSwitch, findsOneWidget);
    expect(
      find.byKey(const ValueKey('automatic-backup-directory-path')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tapDashboardNav(tester, 'heatmap');
    await tester.tap(find.byTooltip('导入备份'));
    await tester.pumpAndSettle();

    expect(find.text(AppLabels.importConfirmMessage), findsOneWidget);
    expect(find.text('继续导入'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard nav reaches feature pages without back buttons',
      (tester) async {
    await openDashboardShell(tester);

    await tapDashboardNav(tester, 'heatmap');
    expect(find.byKey(const ValueKey('heatmap-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('heatmap-back-button')), findsNothing);
    expect(find.text('当前连续'), findsOneWidget);

    await tapDashboardNav(tester, 'problems');
    expect(find.byKey(const ValueKey('problems-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('problems-back-button')), findsNothing);
    expect(find.byKey(const ValueKey('problem-search-field')), findsOneWidget);

    await tapDashboardNav(tester, 'refreshLogs');
    expect(find.byKey(const ValueKey('refresh-logs-page')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('refresh-logs-back-button')), findsNothing);
    expect(find.text('暂无刷新记录'), findsOneWidget);

    await tapDashboardNav(tester, 'contests');
    expect(find.byKey(const ValueKey('contests-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('contests-back-button')), findsNothing);
    expect(find.byKey(const ValueKey('add-contest-button')), findsOneWidget);

    await tapDashboardNav(tester, 'teammates');
    expect(find.byKey(const ValueKey('teammates-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('teammates-back-button')), findsNothing);
    expect(find.byKey(const ValueKey('add-teammate-button')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('refresh-teammates-button')),
      findsOneWidget,
    );
  });

  testWidgets('dashboard summary action cards open feature sections',
      (tester) async {
    await openDashboardShell(tester);

    final problemsAction = find.byKey(const ValueKey('home-action-problems'));
    await Scrollable.ensureVisible(
      tester.elementList(problemsAction).last,
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(problemsAction.last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('problems-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('problems-back-button')), findsNothing);
  });

  testWidgets('toolbar keeps a global manual refresh entry', (tester) async {
    await openDashboardShell(tester);

    expect(
      find.byKey(const ValueKey('toolbar-refresh-button')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('settings enables startup only after tray mode is enabled',
      (tester) async {
    await openDashboardShell(tester);
    await tapDashboardNav(tester, 'settings');

    await tester.tap(find.byKey(const ValueKey('close-to-tray-switch')));
    await tester.pumpAndSettle();

    final startupSwitch = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('launch-at-startup-switch')),
    );
    expect(startupSwitch.onChanged, isNotNull);

    await tester.tap(find.byKey(const ValueKey('dashboard-nav-summary')));
    await tester.pumpAndSettle();
    expect(find.text('放弃未保存的更改？'), findsOneWidget);

    await tester.tap(find.text('放弃更改'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-summary-panel')), findsOneWidget);
  });

  testWidgets('teammates entry opens empty teammates page', (tester) async {
    await openDashboardShell(tester);
    await tapDashboardNav(tester, 'teammates');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('teammates-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-teammate-button')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('refresh-teammates-button')),
      findsOneWidget,
    );
    expect(find.textContaining('今日统计从 04:00 开始'), findsOneWidget);
    expect(find.text('还没有队友，先添加一个公开账号吧。'), findsOneWidget);
  });

  testWidgets('teammates page disables add button at max count',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TeammatesPage(
          data: TeammateStoreData(
            profiles: [
              _teammate('a', 'Ann'),
              _teammate('b', 'Bob'),
              _teammate('c', 'Cal'),
            ],
          ),
          todayRanking: const [],
          recentRankings: const [],
          refreshing: false,
          onBack: () {},
          onSave: (_) async {},
          onDelete: (_) async {},
          onRefreshAll: () async {},
          onRefreshOne: (_) async {},
        ),
      ),
    );

    final addButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('add-teammate-button')),
    );
    expect(addButton.onPressed, isNull);
    expect(find.text('最多添加 3 名队友'), findsOneWidget);
  });

  testWidgets('problems page manual form saves', (tester) async {
    final saved = <ProblemRecord>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ProblemsPage(
          problems: const [],
          onBack: () {},
          onParseLink: (_) async => const ParsedProblemLink(
            title: 'CF 1799A',
            url: 'https://codeforces.com/problemset/problem/1799/A',
            platform: ProblemPlatform.cf,
          ),
          onSave: (problem) async => saved.add(problem),
          onDelete: (_) async {},
          onOpenProblem: (_) async {},
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('add-problem-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('problem-url-field')),
      'https://codeforces.com/problemset/problem/1799/A',
    );
    await tester.enterText(
      find.byKey(const ValueKey('problem-title-field')),
      'CF 1799A',
    );
    await tester.enterText(
      find.byKey(const ValueKey('problem-tags-field')),
      '贪心, 构造',
    );
    await tester.enterText(
      find.byKey(const ValueKey('problem-note-field')),
      '赛后补题',
    );
    await tester.enterText(
      find.byKey(const ValueKey('problem-analysis-field')),
      '注意边界',
    );
    await tester.tap(find.byKey(const ValueKey('save-problem-button')));
    await tester.pumpAndSettle();

    expect(saved, hasLength(1));
    expect(saved.single.title, 'CF 1799A');
    expect(saved.single.tags, hasLength(2));
    expect(saved.single.analysis, isNotEmpty);
  });

  testWidgets('problems page can change status from the card', (tester) async {
    final saved = <ProblemRecord>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ProblemsPage(
          problems: [
            ProblemRecord.create(
              id: 'p1',
              title: 'Todo Problem',
              url: 'https://www.luogu.com.cn/problem/P1001',
              platform: ProblemPlatform.lg,
              status: ProblemStatus.TODO,
              now: DateTime.parse('2026-06-21T12:00:00'),
            ),
          ],
          onBack: () {},
          onParseLink: (_) async => const ParsedProblemLink(
            title: 'Todo Problem',
            url: 'https://www.luogu.com.cn/problem/P1001',
            platform: ProblemPlatform.lg,
          ),
          onSave: (problem) async => saved.add(problem),
          onDelete: (_) async {},
          onOpenProblem: (_) async {},
        ),
      ),
    );

    expect(find.text('待安排'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mark-ac-problem-p1')));
    await tester.pumpAndSettle();

    expect(saved.single.workflowStatus, ProblemWorkflowStatus.mastered);
    expect(find.textContaining('已改为已掌握'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('problem-status-menu-p1')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('problem-status-option-p1-review')));
    await tester.pumpAndSettle();

    expect(saved.last.workflowStatus, ProblemWorkflowStatus.review);
    expect(find.textContaining('已改为待复习'), findsOneWidget);
  });

  testWidgets('problems page uses compact cards with a details dialog',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProblemsPage(
          problems: [
            ProblemRecord.create(
              id: 'p1',
              title: 'Detail Problem A',
              url: 'https://www.luogu.com.cn/problem/P1001',
              platform: ProblemPlatform.lg,
              status: ProblemStatus.TODO,
              tags: const ['dp'],
              note: '赛后补题',
              analysis: '转移要注意边界。',
              now: DateTime.parse('2026-06-21T12:00:00'),
            ),
            ProblemRecord.create(
              id: 'p2',
              title: 'Detail Problem B',
              url: 'https://codeforces.com/problemset/problem/1799/A',
              platform: ProblemPlatform.cf,
              status: ProblemStatus.WA,
              now: DateTime.parse('2026-06-21T12:01:00'),
            ),
          ],
          onBack: () {},
          onParseLink: (_) async => const ParsedProblemLink(
            title: 'Todo Problem',
            url: 'https://www.luogu.com.cn/problem/P1001',
            platform: ProblemPlatform.lg,
          ),
          onSave: (_) async {},
          onDelete: (_) async {},
          onOpenProblem: (_) async {},
        ),
      ),
    );

    expect(find.byType(GridView), findsOneWidget);
    expect(find.byKey(const ValueKey('view-problem-p1')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('view-problem-p1')));
    await tester.pumpAndSettle();

    expect(find.text('备注'), findsOneWidget);
    expect(find.text('赛后补题'), findsOneWidget);
    expect(find.text('题解分析'), findsOneWidget);
    expect(find.text('转移要注意边界。'), findsOneWidget);
  });

  testWidgets('problems page tag chips filter and clear', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProblemsPage(
          problems: [
            ProblemRecord.create(
              id: 'p1',
              title: 'Graph Problem',
              url: 'https://www.luogu.com.cn/problem/P1001',
              platform: ProblemPlatform.lg,
              status: ProblemStatus.TODO,
              tags: const ['Graph'],
              now: DateTime.parse('2026-06-21T12:00:00'),
            ),
            ProblemRecord.create(
              id: 'p2',
              title: 'Greedy Problem',
              url: 'https://codeforces.com/problemset/problem/1799/A',
              platform: ProblemPlatform.cf,
              status: ProblemStatus.AC,
              tags: const ['Greedy'],
              now: DateTime.parse('2026-06-21T12:01:00'),
            ),
          ],
          onBack: () {},
          onParseLink: (_) async => const ParsedProblemLink(
            title: 'Todo Problem',
            url: 'https://www.luogu.com.cn/problem/P1001',
            platform: ProblemPlatform.lg,
          ),
          onSave: (_) async {},
          onDelete: (_) async {},
          onOpenProblem: (_) async {},
        ),
      ),
    );

    expect(find.text('Graph Problem'), findsOneWidget);
    expect(find.text('Greedy Problem'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('problem-tag-filter-Graph')));
    await tester.pumpAndSettle();

    expect(find.text('Graph Problem'), findsOneWidget);
    expect(find.text('Greedy Problem'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('clear-tag-filter-chip')));
    await tester.pumpAndSettle();

    expect(find.text('Graph Problem'), findsOneWidget);
    expect(find.text('Greedy Problem'), findsOneWidget);
  });

  testWidgets('problems page opens problem URL', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ProblemsPage(
          problems: [
            ProblemRecord.create(
              id: 'p1',
              title: 'Todo Problem',
              url: 'https://www.luogu.com.cn/problem/P1001',
              platform: ProblemPlatform.lg,
              status: ProblemStatus.TODO,
              now: DateTime.parse('2026-06-21T12:00:00'),
            ),
          ],
          onBack: () {},
          onParseLink: (_) async => const ParsedProblemLink(
            title: 'Todo Problem',
            url: 'https://www.luogu.com.cn/problem/P1001',
            platform: ProblemPlatform.lg,
          ),
          onSave: (_) async {},
          onDelete: (_) async {},
          onOpenProblem: (problem) async => opened.add(problem.url),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-problem-p1')));
    await tester.pumpAndSettle();

    expect(opened, ['https://www.luogu.com.cn/problem/P1001']);
  });
}

TeammateProfile _teammate(String id, String nickname) {
  return TeammateProfile.create(
    id: id,
    nickname: nickname,
    accounts: const [
      TeammateAccount(platform: 'codeforces', handle: 'alice'),
    ],
    now: DateTime.parse('2026-07-10T12:00:00'),
  );
}
