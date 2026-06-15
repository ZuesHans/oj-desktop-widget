import 'package:flutter_test/flutter_test.dart';
import 'package:oj_float/main.dart';

void main() {
  test('daily summary uses first and last successful snapshots per OJ', () {
    final snapshots = [
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
  });
}
