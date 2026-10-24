import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oj_float/main.dart';

void main() {
  setUp(() {});

  testWidgets('contest page adds a complete manual record', (tester) async {
    await _largeSurface(tester);
    ContestRecord? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: ContestsPage(
          contests: const [],
          rankPoints: const [],
          onBack: () {},
          onSave: (contest) async => saved = contest,
          onDelete: (_) async {},
        ),
      ),
    );

    expect(find.text('还没有比赛记录'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('add-contest-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('contest-title-field')),
      'Weekly Contest',
    );
    await tester.enterText(
      find.byKey(const ValueKey('contest-date-field')),
      '2026-07-27',
    );
    await tester.enterText(
      find.byKey(const ValueKey('contest-rank-field')),
      '3',
    );
    await tester.enterText(
      find.byKey(const ValueKey('contest-total-field')),
      '100',
    );
    await tester.enterText(
      find.byKey(const ValueKey('contest-solved-field')),
      '5',
    );
    await tester.enterText(
      find.byKey(const ValueKey('contest-penalty-field')),
      '720',
    );
    await tester.enterText(
      find.byKey(const ValueKey('contest-note-field')),
      'virtual',
    );
    await tester.tap(find.byKey(const ValueKey('save-contest-button')));
    await tester.pumpAndSettle();

    expect(saved?.title, 'Weekly Contest');
    expect(saved?.rank, 3);
    expect(saved?.totalParticipants, 100);
    expect(saved?.solvedCount, 5);
    expect(saved?.penalty, 720);
    expect(find.text('比赛记录已新增'), findsOneWidget);
  });

  testWidgets('contest page renders chart, edits, and confirms deletion',
      (tester) async {
    await _largeSurface(tester);
    final first = _contest('c1', 'Contest One', '2026-07-20', 12);
    final second = _contest('c2', 'Contest Two', '2026-07-27', 5);
    ContestRecord? saved;
    var deleted = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ContestsPage(
          contests: [second, first],
          rankPoints: const ContestRecordService().buildRankPoints([
            first,
            second,
          ]),
          onBack: () {},
          onSave: (contest) async => saved = contest,
          onDelete: (_) async => deleted += 1,
        ),
      ),
    );

    expect(find.text('最好排名'), findsOneWidget);
    expect(find.text('Contest Two'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('edit-contest-c2')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('contest-title-field')),
      'Contest Two Updated',
    );
    await tester.tap(find.byKey(const ValueKey('save-contest-button')));
    await tester.pumpAndSettle();
    expect(saved?.id, 'c2');
    expect(saved?.title, 'Contest Two Updated');

    await tester.tap(find.byKey(const ValueKey('delete-contest-c1')));
    await tester.pumpAndSettle();
    expect(find.text('删除比赛记录？'), findsOneWidget);
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });

  testWidgets('teammate page adds a profile through the editor',
      (tester) async {
    await _largeSurface(tester);
    TeammateProfile? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: TeammatesPage(
          data: const TeammateStoreData(),
          todayRanking: const [],
          recentRankings: const [],
          refreshing: false,
          onBack: () {},
          onSave: (profile) async => saved = profile,
          onDelete: (_) async {},
          onRefreshAll: () async {},
          onRefreshOne: (_) async {},
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('add-teammate-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('teammate-nickname-field')),
      'Alice',
    );
    await tester.tap(
      find.byKey(const ValueKey('teammate-platform-codeforces')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('teammate-account-codeforces')),
      'alice_cf',
    );
    await tester.tap(find.byKey(const ValueKey('save-teammate-button')));
    await tester.pumpAndSettle();

    expect(saved?.nickname, 'Alice');
    expect(saved?.accounts.single.platform, 'codeforces');
    expect(saved?.accounts.single.handle, 'alice_cf');
    expect(find.text('队友已添加'), findsOneWidget);
  });

  testWidgets('teammate page shows records and action confirmations',
      (tester) async {
    await _largeSurface(tester);
    final profile = TeammateProfile.create(
      id: 't1',
      nickname: 'Alice',
      accounts: const [
        TeammateAccount(platform: 'codeforces', handle: 'alice_cf'),
      ],
      now: DateTime(2026, 7, 27),
    );
    final date = trainingDateFor(DateTime.now());
    final record = TeammateDailyRecord(
      teammateId: 't1',
      trainingDate: date,
      perPlatformDelta: const {'codeforces': 3},
      totalDelta: 3,
      refreshedAt: DateTime.now(),
      errors: const {'leetcode': 'timeout'},
    );
    var refreshAll = 0;
    var refreshOne = 0;
    var deleted = 0;
    TeammateProfile? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: TeammatesPage(
          data: TeammateStoreData(profiles: [profile], records: [record]),
          todayRanking: [TeammateRankEntry(profile: profile, record: record)],
          recentRankings: [
            TeammateDailyRanking(
              trainingDate: date,
              entries: [TeammateRankEntry(profile: profile, record: record)],
            ),
          ],
          refreshing: false,
          onBack: () {},
          onSave: (value) async => saved = value,
          onDelete: (_) async => deleted += 1,
          onRefreshAll: () async => refreshAll += 1,
          onRefreshOne: (_) async => refreshOne += 1,
        ),
      ),
    );

    expect(find.text('+3'), findsWidgets);
    expect(find.text('LeetCode 失败'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('refresh-teammates-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('refresh-teammate-t1')));
    await tester.pumpAndSettle();
    expect(refreshAll, 1);
    expect(refreshOne, 1);

    await tester.tap(find.byKey(const ValueKey('edit-teammate-t1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('teammate-nickname-field')),
      'Alice Updated',
    );
    await tester.tap(find.byKey(const ValueKey('save-teammate-button')));
    await tester.pumpAndSettle();
    expect(saved?.nickname, 'Alice Updated');

    await tester.tap(find.byKey(const ValueKey('delete-teammate-t1')));
    await tester.pumpAndSettle();
    expect(find.text('删除队友？'), findsOneWidget);
    await tester.tap(find.text('删除').last);
    await tester.pumpAndSettle();
    expect(deleted, 1);
  });

  testWidgets('OJ tiles expose exact, estimated, unknown, and retained states',
      (tester) async {
    await _largeSurface(tester);
    final meta = supportedOjs.first;
    final now = DateTime(2026, 7, 27, 12);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              OjTile(
                meta: meta,
                config: const OjAccountConfig(
                  usernames: ['alice', 'bob', 'pending'],
                  enabled: true,
                ),
                results: [
                  FetchResult.success(
                    ojId: meta.id,
                    username: 'alice',
                    solvedCount: 10,
                    fetchedAt: now,
                  ),
                  FetchResult.failure(
                    ojId: meta.id,
                    username: 'bob',
                    error: 'timeout',
                    solvedCount: 20,
                    previousSolvedCount: 20,
                    fetchedAt: now,
                  ),
                ],
                today: 2,
                accountActivity: const {
                  'alice': DailyActivityValue(
                    count: 2,
                    accuracy: DailyActivityAccuracy.estimated,
                  ),
                  'bob': DailyActivityValue(
                    count: null,
                    accuracy: DailyActivityAccuracy.unknown,
                  ),
                },
              ),
              OjTile(
                meta: supportedOjs[1],
                config: null,
                results: const [],
                today: 0,
                accountActivity: const {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('10 (约 +2)'), findsOneWidget);
    expect(find.text('20 (保留)'), findsOneWidget);
    expect(find.text('timeout'), findsOneWidget);
    expect(find.text('pending'), findsOneWidget);
    expect(find.text('今日未知'), findsWidgets);
    expect(find.text('未设置'), findsOneWidget);
  });
}

Future<void> _largeSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

ContestRecord _contest(String id, String title, String date, int rank) {
  return ContestRecord.create(
    id: id,
    title: title,
    date: date,
    rank: rank,
    totalParticipants: 100,
    solvedCount: 4,
    penalty: 600,
    now: DateTime.parse('${date}T20:00:00'),
  );
}
