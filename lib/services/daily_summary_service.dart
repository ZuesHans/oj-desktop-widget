import '../models/fetch_result.dart';
import '../models/solved_snapshot.dart';

class DailySummary {
  const DailySummary({
    required this.date,
    required this.deltas,
    required this.accountDeltas,
    required this.totalDelta,
  });

  factory DailySummary.empty(String date) {
    return DailySummary(
      date: date,
      deltas: const {},
      accountDeltas: const {},
      totalDelta: 0,
    );
  }

  factory DailySummary.fromSnapshots(
      String date, List<SolvedSnapshot> snapshots) {
    final byAccount = <String, List<SolvedSnapshot>>{};
    for (final snapshot in snapshots.where(
      (item) => item.date == date && item.status == FetchStatus.success,
    )) {
      byAccount
          .putIfAbsent('${snapshot.ojId}\u0000${snapshot.username}', () => [])
          .add(snapshot);
    }
    final deltas = <String, int>{};
    final accountDeltas = <String, Map<String, int>>{};
    for (final entry in byAccount.entries) {
      final ordered = [...entry.value]
        ..sort((a, b) => a.fetchedAt.compareTo(b.fetchedAt));
      final ojId = ordered.first.ojId;
      final username = ordered.first.username;
      final first = ordered.first.solvedCount ?? 0;
      final last = ordered.last.solvedCount ?? 0;
      final delta = (last - first).clamp(0, 1 << 31).toInt();
      accountDeltas.putIfAbsent(ojId, () => {})[username] = delta;
      deltas[ojId] = (deltas[ojId] ?? 0) + delta;
    }
    return DailySummary(
      date: date,
      deltas: deltas,
      accountDeltas: accountDeltas,
      totalDelta: deltas.values.fold(0, (sum, item) => sum + item),
    );
  }

  final String date;
  final Map<String, int> deltas;
  final Map<String, Map<String, int>> accountDeltas;
  final int totalDelta;
}
