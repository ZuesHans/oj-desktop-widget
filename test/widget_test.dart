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

  testWidgets('app starts in compact floating mode', (tester) async {
    await tester.pumpWidget(buildTestApp());

    expect(find.text('AC'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('compact-refresh-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('open-dashboard-button')), findsOneWidget);
    expect(find.text('OJ Float'), findsNothing);
    expect(find.text('Codeforces'), findsNothing);
  });

  testWidgets('compact mode opens and closes the dashboard', (tester) async {
    await tester.pumpWidget(buildTestApp());

    await tester.tap(find.byKey(const ValueKey('open-dashboard-button')));
    await tester.pumpAndSettle();

    expect(find.text('OJ Float'), findsOneWidget);
    expect(find.text('Codeforces'), findsOneWidget);
    expect(find.byKey(const ValueKey('compact-mode-button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('compact-mode-button')));
    await tester.pumpAndSettle();

    expect(find.text('AC'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('OJ Float'), findsNothing);
    expect(find.text('Codeforces'), findsNothing);
  });

  testWidgets('compact mode keeps a manual refresh entry', (tester) async {
    await tester.pumpWidget(buildTestApp());

    expect(
        find.byKey(const ValueKey('compact-refresh-button')), findsOneWidget);
    expect(find.byTooltip('Refresh'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('dashboard shows a heatmap entry', (tester) async {
    await tester.pumpWidget(buildTestApp());

    await tester.tap(find.byKey(const ValueKey('open-dashboard-button')));
    await tester.pumpAndSettle();

    expect(find.text('热力图'), findsOneWidget);
    expect(find.byKey(const ValueKey('heatmap-entry-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('export-data-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('import-backup-button')), findsOneWidget);
  });

  testWidgets('dashboard shows a secondary teammates entry', (tester) async {
    await tester.pumpWidget(buildTestApp());

    await tester.tap(find.byKey(const ValueKey('open-dashboard-button')));
    await tester.pumpAndSettle();

    expect(find.text('队友观察'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('teammates-entry-button')), findsOneWidget);
  });

  testWidgets('heatmap entry opens the heatmap page', (tester) async {
    await tester.pumpWidget(buildTestApp());

    await tester.tap(find.byKey(const ValueKey('open-dashboard-button')));
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

  testWidgets('dashboard opens problems page', (tester) async {
    await tester.pumpWidget(buildTestApp());

    await tester.tap(find.byKey(const ValueKey('open-dashboard-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('problems-entry-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('problems-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-problem-button')), findsOneWidget);
  });

  testWidgets('teammates entry opens empty teammates page', (tester) async {
    await tester.pumpWidget(buildTestApp());

    await tester.tap(find.byKey(const ValueKey('open-dashboard-button')));
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
          onMarkAccepted: (_) async {},
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

  testWidgets('problems page can mark an item as AC', (tester) async {
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
          onMarkAccepted: (_) async {},
          onOpenProblem: (_) async {},
        ),
      ),
    );

    expect(find.text('TODO'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mark-ac-problem-p1')));
    await tester.pumpAndSettle();

    expect(find.textContaining('已标记 AC'), findsOneWidget);
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
          onMarkAccepted: (_) async {},
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
