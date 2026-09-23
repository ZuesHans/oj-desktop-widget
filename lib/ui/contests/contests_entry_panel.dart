import 'package:flutter/material.dart';

import '../../models/contest_record.dart';
import '../app_theme.dart';
import '../shared/app_surface_card.dart';

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
    return AppSurfaceCard(
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(appRadiusControl),
              border: Border.all(color: accentColor.withValues(alpha: 0.2)),
            ),
            child: Icon(Icons.emoji_events_outlined, color: accentColor),
          ),
          const SizedBox(width: appSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
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
                  style: TextStyle(
                    color: textSecondaryColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: appSpace2),
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
