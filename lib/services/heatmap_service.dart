part of '../main.dart';

class HeatmapDay {
  const HeatmapDay({required this.date, required this.delta});

  final String date;
  final int delta;

  bool get active => delta > 0;

  int get level {
    if (delta <= 0) {
      return 0;
    }
    if (delta == 1) {
      return 1;
    }
    if (delta <= 3) {
      return 2;
    }
    if (delta <= 6) {
      return 3;
    }
    return 4;
  }
}

class HeatmapSummary {
  const HeatmapSummary({
    required this.days,
    required this.currentStreak,
    required this.longestStreak,
    required this.activeDays,
    required this.totalDelta,
  });

  factory HeatmapSummary.fromSnapshots(
    List<SolvedSnapshot> snapshots, {
    DateTime? today,
    int? weeks,
    DateTime? startDate,
  }) {
    final normalizedToday = _startOfDay(today ?? DateTime.now());
    final deltasByDate = _dailyDeltasByDate(snapshots);
    final days = <HeatmapDay>[];
    final start = weeks == null
        ? _startOfWeek(startDate ?? _heatmapDefaultStartDate)
        : _startOfWeek(
            normalizedToday.subtract(
              Duration(days: (weeks.clamp(1, 104).toInt() - 1) * 7),
            ),
          );
    final end = _endOfWeek(normalizedToday);
    for (var date = start;
        !date.isAfter(end);
        date = date.add(const Duration(days: 1))) {
      final key = dateKey(date);
      days.add(HeatmapDay(date: key, delta: deltasByDate[key] ?? 0));
    }

    return HeatmapSummary(
      days: List.unmodifiable(days),
      currentStreak: _currentStreak(deltasByDate, normalizedToday),
      longestStreak: _longestStreak(deltasByDate),
      activeDays: days.where((day) => day.active).length,
      totalDelta: days.fold(0, (sum, day) => sum + day.delta),
    );
  }

  final List<HeatmapDay> days;
  final int currentStreak;
  final int longestStreak;
  final int activeDays;
  final int totalDelta;
}

Map<String, int> _dailyDeltasByDate(List<SolvedSnapshot> snapshots) {
  final dates = {
    for (final snapshot in snapshots) snapshot.date,
  }.toList()
    ..sort();
  return {
    for (final date in dates)
      date: DailySummary.fromSnapshots(date, snapshots).totalDelta,
  };
}

DateTime _startOfWeek(DateTime date) {
  final normalized = _startOfDay(date);
  return normalized.subtract(Duration(days: normalized.weekday % 7));
}

DateTime _endOfWeek(DateTime date) {
  return _startOfWeek(date).add(const Duration(days: 6));
}

int _currentStreak(Map<String, int> deltasByDate, DateTime today) {
  var count = 0;
  var cursor = _startOfDay(today);
  while ((deltasByDate[dateKey(cursor)] ?? 0) > 0) {
    count += 1;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return count;
}

int _longestStreak(Map<String, int> deltasByDate) {
  if (deltasByDate.isEmpty) {
    return 0;
  }
  final dates = deltasByDate.keys.map(_dateFromKey).toList()..sort();
  var longest = 0;
  var current = 0;
  var cursor = dates.first;
  final end = dates.last;
  while (!cursor.isAfter(end)) {
    if ((deltasByDate[dateKey(cursor)] ?? 0) > 0) {
      current += 1;
      if (current > longest) {
        longest = current;
      }
    } else {
      current = 0;
    }
    cursor = cursor.add(const Duration(days: 1));
  }
  return longest;
}

DateTime _dateFromKey(String value) {
  return DateTime(
    int.parse(value.substring(0, 4)),
    int.parse(value.substring(5, 7)),
    int.parse(value.substring(8, 10)),
  );
}

DateTime _startOfDay(DateTime date) {
  final local = date.toLocal();
  return DateTime(local.year, local.month, local.day);
}
