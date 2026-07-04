import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oj_float/main.dart';

void main() {
  Widget buildTestApp() {
    return const OjFloatApp(
      enablePlatformIntegration: false,
      autoInitializeController: false,
    );
  }

  Widget buildConfiguredTestApp(AppConfig config) {
    return OjFloatApp(
      initialConfig: config,
      enablePlatformIntegration: false,
      autoInitializeController: false,
    );
  }

  testWidgets('app starts in compact floating mode', (tester) async {
    await tester.pumpWidget(buildTestApp());

    expect(find.text('总通过'), findsOneWidget);
    expect(find.textContaining('今日'), findsOneWidget);
    expect(find.byKey(const ValueKey('compact-widget')), findsOneWidget);
    expect(find.text('OJ 悬浮窗'), findsNothing);
    expect(find.text('Codeforces'), findsNothing);
  });

  testWidgets('compact mode opens and closes the large float', (tester) async {
    await tester.pumpWidget(buildTestApp());

    await tester.tap(find.byKey(const ValueKey('compact-widget')));
    await tester.pumpAndSettle();

    expect(find.text('OJ 悬浮窗'), findsOneWidget);
    expect(find.byKey(const ValueKey('open-dashboard-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('refresh-logs-entry-button')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('compact-mode-button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('compact-mode-button')));
    await tester.pumpAndSettle();

    expect(find.text('总通过'), findsOneWidget);
    expect(find.textContaining('今日'), findsOneWidget);
    expect(find.text('OJ 悬浮窗'), findsNothing);
    expect(find.text('Codeforces'), findsNothing);
  });

  testWidgets('compact mode can open dashboard directly', (tester) async {
    await tester.pumpWidget(
      buildConfiguredTestApp(
        _appConfig(compactClickTarget: CompactClickTarget.dashboard),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('compact-widget')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('dashboard-shell')), findsOneWidget);
    expect(find.byKey(const ValueKey('dashboard-nav')), findsOneWidget);
    expect(find.byKey(const ValueKey('open-dashboard-button')), findsNothing);
  });

  testWidgets('large float opens dashboard with left navigation',
      (tester) async {
    await tester.pumpWidget(buildTestApp());

    await tester.tap(find.byKey(const ValueKey('compact-widget')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-dashboard-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('dashboard-shell')), findsOneWidget);
    expect(find.byKey(const ValueKey('dashboard-nav')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-summary-panel')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('home-empty-account-state')), findsOneWidget);
    expect(find.text('今天进度'), findsOneWidget);

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
    expect(find.text('大浮窗显示模块'), findsOneWidget);
  });

  testWidgets('dashboard summary action cards open feature sections',
      (tester) async {
    await tester.pumpWidget(buildTestApp());

    await tester.tap(find.byKey(const ValueKey('compact-widget')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-dashboard-button')));
    await tester.pumpAndSettle();

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

  testWidgets('compact mode keeps a manual refresh entry', (tester) async {
    await tester.pumpWidget(buildTestApp());

    expect(find.byKey(const ValueKey('compact-widget')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('large float shows a heatmap entry', (tester) async {
    await tester.pumpWidget(buildTestApp());

    await tester.tap(find.byKey(const ValueKey('compact-widget')));
    await tester.pumpAndSettle();

    expect(find.text('热力图'), findsOneWidget);
    expect(find.byKey(const ValueKey('heatmap-entry-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('export-data-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('import-backup-button')), findsOneWidget);
  });

  testWidgets('large float shows a secondary teammates entry', (tester) async {
    await tester.pumpWidget(buildTestApp());

    await tester.tap(find.byKey(const ValueKey('compact-widget')));
    await tester.pumpAndSettle();

    expect(find.text('队友观察'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('teammates-entry-button')), findsOneWidget);
  });

  testWidgets('heatmap entry opens the heatmap page', (tester) async {
    await tester.pumpWidget(buildTestApp());

    await tester.tap(find.byKey(const ValueKey('compact-widget')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('heatmap-entry-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('heatmap-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('heatmap-back-button')), findsOneWidget);
    expect(find.text('当前连续'), findsOneWidget);
    expect(find.byTooltip('更早'), findsOneWidget);
    expect(find.byTooltip('更新'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('heatmap-back-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('heatmap-page')), findsNothing);
    expect(find.byKey(const ValueKey('heatmap-entry-button')), findsOneWidget);
  });

  testWidgets('large float opens problems page', (tester) async {
    await tester.pumpWidget(buildTestApp());

    await tester.tap(find.byKey(const ValueKey('compact-widget')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('problems-entry-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('problems-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-problem-button')), findsOneWidget);
  });

  testWidgets('large float opens refresh logs page', (tester) async {
    await tester.pumpWidget(buildTestApp());

    await tester.tap(find.byKey(const ValueKey('compact-widget')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('refresh-logs-entry-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('refresh-logs-page')), findsOneWidget);
    expect(find.text('暂无刷新记录'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('refresh-logs-back-button')),
      findsOneWidget,
    );
  });

  testWidgets('teammates entry opens empty teammates page', (tester) async {
    await tester.pumpWidget(buildTestApp());

    await tester.tap(find.byKey(const ValueKey('compact-widget')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('teammates-entry-button')),
      120,
    );
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const ValueKey('teammates-entry-button'))),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('teammates-entry-button')));
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

    expect(find.text('待做'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mark-ac-problem-p1')));
    await tester.pumpAndSettle();

    expect(saved.single.status, ProblemStatus.AC);
    expect(find.textContaining('已改为已通过'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('problem-status-menu-p1')));
    await tester.pumpAndSettle();
    await tester
        .tap(find.byKey(const ValueKey('problem-status-option-p1-REVIEW')));
    await tester.pumpAndSettle();

    expect(saved.last.status, ProblemStatus.REVIEW);
    expect(find.textContaining('已改为复盘中'), findsOneWidget);
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

AppConfig _appConfig({
  CompactClickTarget compactClickTarget = CompactClickTarget.largeFloat,
}) {
  return AppConfig.defaults().copyWith(compactClickTarget: compactClickTarget);
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
