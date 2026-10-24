import '../models/fetch_result.dart';
import '../models/solved_snapshot.dart';

class DailyActivityValue {
  const DailyActivityValue({required this.count, required this.accuracy});

  final int? count;
  final DailyActivityAccuracy accuracy;

  bool get known => count != null;
}

class DailySummary {
  const DailySummary({
    required this.date,
    required this.accountActivities,
  });

  factory DailySummary.empty(String date) {
    return DailySummary(date: date, accountActivities: const {});
  }

  factory DailySummary.fromSnapshots(
    String date,
    List<SolvedSnapshot> snapshots,
  ) {
    final currentByAccount = <String, List<SolvedSnapshot>>{};
    for (final snapshot in snapshots.where(
      (item) => item.date == date && item.status == FetchStatus.success,
    )) {
      currentByAccount
          .putIfAbsent(_accountKey(snapshot), () => [])
          .add(snapshot);
    }

    final activities = <String, Map<String, DailyActivityValue>>{};
    for (final entry in currentByAccount.entries) {
      final ordered = [...entry.value]
        ..sort((a, b) => a.fetchedAt.compareTo(b.fetchedAt));
      final latest = ordered.last;
      final exact = ordered.reversed.cast<SolvedSnapshot?>().firstWhere(
            (item) =>
                item?.dailyActivityAccuracy == DailyActivityAccuracy.exact &&
                item?.dailyAcceptedCount != null,
            orElse: () => null,
          );

      DailyActivityValue value;
      if (exact != null) {
        value = DailyActivityValue(
          count: exact.dailyAcceptedCount,
          accuracy: DailyActivityAccuracy.exact,
        );
      } else {
        final previous = _latestPreviousSnapshot(
          snapshots,
          latest.ojId,
          latest.username,
          date,
        );
        if (previous?.solvedCount != null && latest.solvedCount != null) {
          value = DailyActivityValue(
            count: (latest.solvedCount! - previous!.solvedCount!)
                .clamp(0, 1 << 31)
                .toInt(),
            accuracy: DailyActivityAccuracy.estimated,
          );
        } else {
          value = const DailyActivityValue(
            count: null,
            accuracy: DailyActivityAccuracy.unknown,
          );
        }
      }
      activities.putIfAbsent(
        latest.ojId,
        () => <String, DailyActivityValue>{},
      )[latest.username] = value;
    }

    return DailySummary(
      date: date,
      accountActivities:
          Map<String, Map<String, DailyActivityValue>>.unmodifiable({
        for (final entry in activities.entries)
          entry.key: Map<String, DailyActivityValue>.unmodifiable(entry.value),
      }),
    );
  }

  final String date;
  final Map<String, Map<String, DailyActivityValue>> accountActivities;

  Map<String, Map<String, int>> get accountDeltas =>
      Map<String, Map<String, int>>.unmodifiable({
        for (final platform in accountActivities.entries)
          platform.key: Map<String, int>.unmodifiable({
            for (final account in platform.value.entries)
              if (account.value.count != null)
                account.key: account.value.count!,
          }),
      });

  Map<String, int> get deltas => Map.unmodifiable({
        for (final platform in accountActivities.entries)
          platform.key: platform.value.values
              .where((value) => value.count != null)
              .fold(0, (sum, value) => sum + value.count!),
      });

  int get totalDelta => deltas.values.fold(0, (sum, item) => sum + item);

  bool get hasUnknown => accountActivities.values
      .expand((items) => items.values)
      .any((value) => value.accuracy == DailyActivityAccuracy.unknown);

  bool get hasEstimated => accountActivities.values
      .expand((items) => items.values)
      .any((value) => value.accuracy == DailyActivityAccuracy.estimated);

  DailyActivityAccuracy accuracyForPlatform(String ojId) {
    final values = accountActivities[ojId]?.values ?? const [];
    if (values.any(
      (value) => value.accuracy == DailyActivityAccuracy.unknown,
    )) {
      return DailyActivityAccuracy.unknown;
    }
    if (values.any(
      (value) => value.accuracy == DailyActivityAccuracy.estimated,
    )) {
      return DailyActivityAccuracy.estimated;
    }
    return DailyActivityAccuracy.exact;
  }
}

SolvedSnapshot? _latestPreviousSnapshot(
  List<SolvedSnapshot> snapshots,
  String ojId,
  String username,
  String date,
) {
  SolvedSnapshot? latest;
  for (final snapshot in snapshots) {
    if (snapshot.status != FetchStatus.success ||
        snapshot.solvedCount == null ||
        snapshot.ojId != ojId ||
        snapshot.username != username ||
        snapshot.date.compareTo(date) >= 0) {
      continue;
    }
    if (latest == null || snapshot.fetchedAt.isAfter(latest.fetchedAt)) {
      latest = snapshot;
    }
  }
  return latest;
}

String _accountKey(SolvedSnapshot snapshot) {
  return '${snapshot.ojId}\u0000${snapshot.username}';
}
