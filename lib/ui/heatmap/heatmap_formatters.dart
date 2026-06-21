import 'package:flutter/material.dart';

import '../../services/heatmap_service.dart';
import '../app_theme.dart';

String heatmapMonthName(DateTime date) {
  return '${date.month}';
}

String heatmapShortDate(String date) {
  final parsed = DateTime.parse(date);
  return '${parsed.month}/${parsed.day}';
}

class HeatmapWeekdayLabels extends StatelessWidget {
  const HeatmapWeekdayLabels({super.key});

  @override
  Widget build(BuildContext context) {
    const labels = ['', '一', '', '三', '', '五', ''];
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Column(
        children: [
          for (final label in labels)
            SizedBox(
              width: 22,
              height: 16,
              child: Text(
                label,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 9,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class HeatmapStat extends StatelessWidget {
  const HeatmapStat({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class HeatmapWeek extends StatelessWidget {
  const HeatmapWeek({super.key, required this.days});

  final List<HeatmapDay> days;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Column(
        children: days.map((day) => _HeatmapCell(day: day)).toList(),
      ),
    );
  }
}

class _HeatmapCell extends StatelessWidget {
  const _HeatmapCell({required this.day});

  final HeatmapDay day;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${day.date}: +${day.delta}',
      child: Container(
        width: 12,
        height: 12,
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: _heatmapColor(day.level),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

List<List<HeatmapDay>> heatmapWeeks(List<HeatmapDay> days) {
  final weeks = <List<HeatmapDay>>[];
  for (var index = 0; index < days.length; index += 7) {
    final end = index + 7 > days.length ? days.length : index + 7;
    weeks.add(days.sublist(index, end));
  }
  return weeks;
}

Color _heatmapColor(int level) {
  return heatmapLevelColors[level.clamp(0, heatmapLevelColors.length - 1)];
}
