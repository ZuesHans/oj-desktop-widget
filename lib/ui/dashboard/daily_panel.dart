import 'package:flutter/material.dart';

import '../../core/oj_catalog.dart';
import '../../models/oj_state.dart';
import '../app_theme.dart';
import '../shared/pill.dart';

class DailyPanel extends StatelessWidget {
  const DailyPanel({super.key, required this.state});

  final OjState state;

  @override
  Widget build(BuildContext context) {
    final summary = state.todaySummary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '每日总结',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              Pill(label: summary.date),
            ],
          ),
          const SizedBox(height: 10),
          if (summary.deltas.isEmpty)
            const Text('暂无今日快照', style: TextStyle(color: textSecondaryColor))
          else
            ...supportedOjs.map((meta) {
              final delta = summary.deltas[meta.id];
              if (delta == null) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(child: Text(meta.name)),
                    Text('+$delta'),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
