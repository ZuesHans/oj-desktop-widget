import 'package:flutter/material.dart';

import '../../models/contest_record.dart';
import '../app_theme.dart';

class ContestsEntryPanel extends StatelessWidget {
  const ContestsEntryPanel({
    super.key,
    required this.contests,
    required this.onOpen,
  });

  final List<ContestRecord> contests;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final latest = contests.isEmpty ? null : contests.first;
    final bestRank = contests.isEmpty
        ? null
        : contests.map((contest) => contest.rank).reduce(
              (value, element) => value < element ? value : element,
            );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_outlined, color: accentColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '比赛记录',
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  contests.isEmpty
                      ? '记录训练赛、校内赛和模拟赛排名'
                      : '共 ${contests.length} 场 · 最近 #${latest!.rank} · 最好 #$bestRank',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: textSecondaryColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            key: const ValueKey('contests-entry-button'),
            onPressed: onOpen,
            icon: const Icon(Icons.show_chart, size: 18),
            label: const Text('打开'),
          ),
        ],
      ),
    );
  }
}
