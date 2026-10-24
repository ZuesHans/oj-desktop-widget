String dateKey(DateTime date) {
  final local = date.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

DateTime trainingDayStartFor(DateTime date) {
  final local = date.toLocal();
  final todayStart = DateTime(local.year, local.month, local.day, 4);
  return local.isBefore(todayStart)
      ? todayStart.subtract(const Duration(days: 1))
      : todayStart;
}

DateTime trainingDayStartFromKey(String value) {
  final date = DateTime.parse(value);
  return DateTime(date.year, date.month, date.day, 4);
}

DateTime trainingDayEndFromKey(String value) {
  return trainingDayStartFromKey(value).add(const Duration(days: 1));
}

String formatTime(DateTime date) {
  final local = date.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String trainingDateFor(DateTime now) {
  return dateKey(trainingDayStartFor(now));
}

bool isSameTrainingDate(DateTime a, DateTime b) {
  return trainingDateFor(a) == trainingDateFor(b);
}

bool shouldAutoRefreshTeammates(
  DateTime now,
  String? lastAutoRefreshTrainingDate,
) {
  return trainingDateFor(now) != lastAutoRefreshTrainingDate;
}

bool isValidDateKey(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) {
    return false;
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  return date.year == year && date.month == month && date.day == day;
}
