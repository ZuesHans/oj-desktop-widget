import 'package:flutter/material.dart';

import '../../core/solved_totals.dart';
import '../../core/time.dart';
import '../../models/oj_state.dart';
import '../app_theme.dart';
import '../shared/pill.dart';

class SummaryPanel extends StatelessWidget {
  const SummaryPanel({super.key, required this.state});

  final OjState state;

  @override
  Widget build(BuildContext context) {
    final totalSolved = totalSolvedFromLatest(state.latest);
    final today = state.todaySummary.totalDelta;
    final updatedAt = state.latest.values
        .expand((items) => items)
        .where((item) => item.fetchedAt != null)
        .map((item) => item.fetchedAt!)
        .fold<DateTime?>(null, (latest, item) {
      if (latest == null || item.isAfter(latest)) {
        return item;
      }
      return latest;
    });

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('总通过', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            '$totalSolved',
            style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w800),
          ),
          Row(
            children: [
              Pill(label: '今日 +$today'),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  updatedAt == null ? '尚未刷新' : '更新 ${formatTime(updatedAt)}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: textSecondaryColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
