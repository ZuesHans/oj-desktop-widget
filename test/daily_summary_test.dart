import 'package:flutter_test/flutter_test.dart';
import 'package:oj_float/main.dart';

void main() {
  test('daily summary estimates from the latest previous-day baseline', () {
    final snapshots = [
      SolvedSnapshot(
        date: '2026-06-14',
        fetchedAt: DateTime.parse('2026-06-15T03:30:00'),
        ojId: 'codeforces',
        username: 'alice',
        status: FetchStatus.success,
        solvedCount: 10,
      ),
      SolvedSnapshot(
        date: '2026-06-15',
        fetchedAt: DateTime.parse('2026-06-15T08:00:00'),
        ojId: 'codeforces',
        username: 'alice',
        status: FetchStatus.success,
        solvedCount: 10,
      ),
      SolvedSnapshot(
        date: '2026-06-15',
        fetchedAt: DateTime.parse('2026-06-15T09:00:00'),
        ojId: 'codeforces',
        username: 'alice',
        status: FetchStatus.failure,
        error: 'network',
      ),
      SolvedSnapshot(
        date: '2026-06-15',
        fetchedAt: DateTime.parse('2026-06-15T22:00:00'),
        ojId: 'codeforces',
        username: 'alice',
        status: FetchStatus.success,
        solvedCount: 14,
      ),
      SolvedSnapshot(
        date: '2026-06-15',
        fetchedAt: DateTime.parse('2026-06-15T20:00:00'),
        ojId: 'leetcode',
        username: 'alice',
        status: FetchStatus.success,
        solvedCount: 4,
      ),
    ];

    final summary = DailySummary.fromSnapshots('2026-06-15', snapshots);

    expect(summary.deltas['codeforces'], 4);
    expect(summary.deltas['leetcode'], 0);
    expect(summary.totalDelta, 4);
    expect(summary.hasEstimated, isTrue);
    expect(summary.hasUnknown, isTrue);
  });

  test('daily summary groups by OJ and username before platform total', () {
    final snapshots = [
      SolvedSnapshot(
        date: '2026-06-14',
        fetchedAt: DateTime.parse('2026-06-15T03:00:00'),
        ojId: 'codeforces',
        username: 'a',
        status: FetchStatus.success,
        solvedCount: 10,
      ),
      SolvedSnapshot(
        date: '2026-06-14',
        fetchedAt: DateTime.parse('2026-06-15T03:10:00'),
        ojId: 'codeforces',
        username: 'b',
        status: FetchStatus.success,
        solvedCount: 100,
      ),
      SolvedSnapshot(
        date: '2026-06-15',
        fetchedAt: DateTime.parse('2026-06-15T08:00:00'),
        ojId: 'codeforces',
        username: 'a',
        status: FetchStatus.success,
        solvedCount: 10,
      ),
      SolvedSnapshot(
        date: '2026-06-15',
        fetchedAt: DateTime.parse('2026-06-15T12:00:00'),
        ojId: 'codeforces',
        username: 'b',
        status: FetchStatus.success,
        solvedCount: 100,
      ),
      SolvedSnapshot(
        date: '2026-06-15',
        fetchedAt: DateTime.parse('2026-06-15T20:00:00'),
        ojId: 'codeforces',
        username: 'a',
        status: FetchStatus.success,
        solvedCount: 13,
      ),
      SolvedSnapshot(
        date: '2026-06-15',
        fetchedAt: DateTime.parse('2026-06-15T22:00:00'),
        ojId: 'codeforces',
        username: 'b',
        status: FetchStatus.success,
        solvedCount: 102,
      ),
    ];

    final summary = DailySummary.fromSnapshots('2026-06-15', snapshots);

    expect(summary.accountDeltas['codeforces']?['a'], 3);
    expect(summary.accountDeltas['codeforces']?['b'], 2);
    expect(summary.deltas['codeforces'], 5);
    expect(summary.totalDelta, 5);
  });

  test('exact daily activity counts work on the first refresh of the day', () {
    final summary = DailySummary.fromSnapshots('2026-06-15', [
      SolvedSnapshot(
        date: '2026-06-15',
        fetchedAt: DateTime.parse('2026-06-15T08:00:00'),
        ojId: 'atcoder',
        username: 'alice',
        status: FetchStatus.success,
        solvedCount: 200,
        dailyAcceptedCount: 3,
        dailyActivityAccuracy: DailyActivityAccuracy.exact,
      ),
    ]);

    expect(summary.deltas['atcoder'], 3);
    expect(summary.accountDeltas['atcoder']?['alice'], 3);
    expect(
      summary.accuracyForPlatform('atcoder'),
      DailyActivityAccuracy.exact,
    );
  });

  test('missing cumulative baseline is unknown instead of zero', () {
    final summary = DailySummary.fromSnapshots('2026-06-15', [
      SolvedSnapshot(
        date: '2026-06-15',
        fetchedAt: DateTime.parse('2026-06-15T08:00:00'),
        ojId: 'leetcode',
        username: 'alice',
        status: FetchStatus.success,
        solvedCount: 10,
      ),
    ]);

    expect(summary.accountDeltas['leetcode'], isEmpty);
    expect(summary.hasUnknown, isTrue);
    expect(
      summary.accountActivities['leetcode']?['alice']?.count,
      isNull,
    );
  });
}
