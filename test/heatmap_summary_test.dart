import 'package:flutter_test/flutter_test.dart';
import 'package:oj_float/main.dart';

void main() {
  test('empty snapshots produce empty heatmap and zero streaks', () {
    final summary = HeatmapSummary.fromSnapshots(
      const [],
      today: DateTime.parse('2026-06-16T10:00:00'),
      weeks: 1,
    );

    expect(summary.days, isEmpty);
    expect(summary.currentStreak, 0);
    expect(summary.longestStreak, 0);
  });

  test('day with positive delta is active', () {
    final summary = HeatmapSummary.fromSnapshots(
      _activeDay('2026-06-16', from: 10, to: 12),
      today: DateTime.parse('2026-06-16T10:00:00'),
      weeks: 1,
    );

    final day = summary.days.singleWhere((day) => day.date == '2026-06-16');
    expect(day.delta, 2);
    expect(day.active, isTrue);
  });

  test('current streak is zero when today is not active', () {
    final summary = HeatmapSummary.fromSnapshots(
      _activeDay('2026-06-15', from: 10, to: 12),
      today: DateTime.parse('2026-06-16T10:00:00'),
      weeks: 1,
    );

    expect(summary.currentStreak, 0);
  });

  test('current streak counts today yesterday and the day before', () {
    final snapshots = [
      ..._activeDay('2026-06-14', from: 1, to: 2),
      ..._activeDay('2026-06-15', from: 2, to: 3),
      ..._activeDay('2026-06-16', from: 3, to: 4),
    ];

    final summary = HeatmapSummary.fromSnapshots(
      snapshots,
      today: DateTime.parse('2026-06-16T10:00:00'),
      weeks: 1,
    );

    expect(summary.currentStreak, 3);
  });

  test('longest streak breaks on an inactive day', () {
    final snapshots = [
      ..._activeDay('2026-06-10', from: 1, to: 2),
      ..._activeDay('2026-06-11', from: 2, to: 3),
      _snapshot('2026-06-12', 'a', 3, hour: 8),
      _snapshot('2026-06-12', 'a', 3, hour: 20),
      ..._activeDay('2026-06-13', from: 3, to: 4),
      ..._activeDay('2026-06-14', from: 4, to: 5),
      ..._activeDay('2026-06-15', from: 5, to: 6),
    ];

    final summary = HeatmapSummary.fromSnapshots(
      snapshots,
      today: DateTime.parse('2026-06-16T10:00:00'),
      weeks: 2,
    );

    expect(summary.longestStreak, 3);
  });

  test('same day multiple accounts are summed', () {
    final snapshots = [
      _snapshot('2026-06-16', 'a', 10, hour: 8),
      _snapshot('2026-06-16', 'a', 13, hour: 20),
      _snapshot('2026-06-16', 'b', 100, hour: 9),
      _snapshot('2026-06-16', 'b', 102, hour: 21),
    ];

    final summary = HeatmapSummary.fromSnapshots(
      snapshots,
      today: DateTime.parse('2026-06-16T10:00:00'),
      weeks: 1,
    );

    final day = summary.days.singleWhere((day) => day.date == '2026-06-16');
    expect(day.delta, 5);
    expect(summary.totalDelta, 5);
  });

  test('heatmap day levels follow contribution intensity buckets', () {
    expect(const HeatmapDay(date: '2026-06-16', delta: 0).level, 0);
    expect(const HeatmapDay(date: '2026-06-16', delta: 1).level, 1);
    expect(const HeatmapDay(date: '2026-06-16', delta: 3).level, 2);
    expect(const HeatmapDay(date: '2026-06-16', delta: 6).level, 3);
    expect(const HeatmapDay(date: '2026-06-16', delta: 7).level, 4);
  });
}

List<SolvedSnapshot> _activeDay(String date,
    {required int from, required int to}) {
  return [
    _snapshot(date, 'a', from, hour: 8),
    _snapshot(date, 'a', to, hour: 20),
  ];
}

SolvedSnapshot _snapshot(String date, String username, int solvedCount,
    {required int hour}) {
  return SolvedSnapshot(
    date: date,
    fetchedAt:
        DateTime.parse('${date}T${hour.toString().padLeft(2, '0')}:00:00'),
    ojId: 'codeforces',
    username: username,
    status: FetchStatus.success,
    solvedCount: solvedCount,
  );
}
