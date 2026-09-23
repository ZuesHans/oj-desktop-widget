import 'package:flutter/material.dart';

import '../../models/teammate.dart';
import '../app_theme.dart';
import '../shared/app_surface_card.dart';

class TeammatesEntryPanel extends StatelessWidget {
  const TeammatesEntryPanel({
    super.key,
    required this.teammates,
    required this.todayRanking,
    required this.onOpen,
  });

  final TeammateStoreData teammates;
  final List<TeammateRankEntry> todayRanking;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final leader = todayRanking.isEmpty ? null : todayRanking.first;
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
            child: Icon(Icons.groups_2_outlined, color: accentColor),
          ),
          const SizedBox(width: appSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '队友观察',
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  teammates.profiles.isEmpty
                      ? '添加最多 3 名队友，看看今天谁多刷了几题'
                      : leader == null
                          ? '共 ${teammates.profiles.length} 人 · 刷新后生成今日排行'
                          : '共 ${teammates.profiles.length} 人 · 今日领先 ${leader.profile.nickname} +${leader.record.totalDelta}',
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
            key: const ValueKey('teammates-entry-button'),
            onPressed: onOpen,
            icon: const Icon(Icons.leaderboard_outlined, size: 18),
            label: const Text('打开'),
          ),
        ],
      ),
    );
  }
}
