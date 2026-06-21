import 'package:flutter/material.dart';

import '../../services/heatmap_service.dart';
import '../app_theme.dart';
import 'heatmap_formatters.dart';

class HeatmapDialog extends StatefulWidget {
  const HeatmapDialog({super.key, required this.summary});

  final HeatmapSummary summary;

  @override
  State<HeatmapDialog> createState() => _HeatmapDialogState();
}

class _HeatmapDialogState extends State<HeatmapDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('heatmap-dialog'),
      title: const Text('热力图'),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                HeatmapStat(
                    label: '当前连续', value: '${widget.summary.currentStreak} 天'),
                HeatmapStat(
                    label: '最长连续', value: '${widget.summary.longestStreak} 天'),
                HeatmapStat(
                    label: '活跃天数', value: '${widget.summary.activeDays}'),
                HeatmapStat(
                    label: '累计新增', value: '+${widget.summary.totalDelta}'),
              ],
            ),
            const SizedBox(height: 16),
            HeatmapGrid(days: widget.summary.days),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

class HeatmapGrid extends StatefulWidget {
  const HeatmapGrid({super.key, required this.days});

  final List<HeatmapDay> days;

  @override
  State<HeatmapGrid> createState() => HeatmapGridState();
}

class HeatmapGridState extends State<HeatmapGrid> {
  static const _weeksPerPage = 12;
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = 0;
  }

  @override
  void didUpdateWidget(covariant HeatmapGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.days.length != widget.days.length) {
      _page = _page.clamp(0, _lastPage).toInt();
    }
  }

  int get _lastPage {
    final weekCount = heatmapWeeks(widget.days).length;
    if (weekCount == 0) {
      return 0;
    }
    return ((weekCount - 1) / _weeksPerPage).floor();
  }

  @override
  Widget build(BuildContext context) {
    final weeks = heatmapWeeks(widget.days);
    final pageCount = _lastPage + 1;
    final end =
        (weeks.length - _page * _weeksPerPage).clamp(0, weeks.length).toInt();
    final start = (end - _weeksPerPage).clamp(0, weeks.length).toInt();
    final visibleWeeks = weeks.sublist(start, end);
    final rangeText = visibleWeeks.isEmpty
        ? ''
        : '${heatmapShortDate(visibleWeeks.first.first.date)} - '
            '${heatmapShortDate(visibleWeeks.last.last.date)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                rangeText,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: textSecondaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: '更早',
              visualDensity: VisualDensity.compact,
              onPressed:
                  _page == _lastPage ? null : () => setState(() => _page += 1),
              icon: const Icon(Icons.chevron_left, size: 20),
            ),
            Text(
              '${pageCount - _page}/$pageCount',
              style: const TextStyle(color: textSecondaryColor, fontSize: 12),
            ),
            IconButton(
              tooltip: '更新',
              visualDensity: VisualDensity.compact,
              onPressed: _page == 0 ? null : () => setState(() => _page -= 1),
              icon: const Icon(Icons.chevron_right, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 26, bottom: 6),
              child: Row(
                children: _heatmapMonthLabels(visibleWeeks)
                    .map((label) => _HeatmapMonthCell(label: label))
                    .toList(),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const HeatmapWeekdayLabels(),
                ...visibleWeeks.map((week) => HeatmapWeek(days: week)),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _HeatmapMonthCell extends StatelessWidget {
  const _HeatmapMonthCell({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 12,
      child: Text(
        label,
        softWrap: false,
        overflow: TextOverflow.clip,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 10,
        ),
      ),
    );
  }
}

List<String> _heatmapMonthLabels(List<List<HeatmapDay>> weeks) {
  DateTime? previousMonth;
  return [
    for (var index = 0; index < weeks.length; index += 1)
      () {
        final week = weeks[index];
        final labelDate = _heatmapMonthLabelDate(week);
        final shouldLabel = labelDate != null &&
            (index == 0 ||
                previousMonth == null ||
                labelDate.year != previousMonth!.year ||
                labelDate.month != previousMonth!.month);
        if (labelDate != null) {
          previousMonth = labelDate;
        }
        return shouldLabel ? heatmapMonthName(labelDate) : '';
      }(),
  ];
}

DateTime? _heatmapMonthLabelDate(List<HeatmapDay> week) {
  if (week.isEmpty) {
    return null;
  }
  for (final day in week) {
    final date = DateTime.parse(day.date);
    if (date.day == 1) {
      return date;
    }
  }
  return DateTime.parse(week.first.date);
}
