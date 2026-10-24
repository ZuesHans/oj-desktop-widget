import 'package:flutter/material.dart';
import '../../models/teammate.dart';
import '../shared/workspace_entry_card.dart';

class TeammatesEntryPanel extends StatelessWidget {
  const TeammatesEntryPanel(
      {super.key,
      required this.teammates,
      required this.todayRanking,
      required this.onOpen});
  final TeammateStoreData teammates;
  final List<TeammateRankEntry> todayRanking;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final leader = todayRanking.isEmpty ? null : todayRanking.first;
    return WorkspaceEntryCard(
      title: '队友观察',
      icon: Icons.groups_2_outlined,
      description: '轻量比较公开账号的训练进展。',
      onOpen: onOpen,
      openKey: const ValueKey('teammates-entry-button'),
      child: Text(
          teammates.profiles.isEmpty
              ? '添加公开账号，开始观察训练节奏。'
              : leader == null
                  ? '共 ${teammates.profiles.length} 人 · 刷新后生成今日排行'
                  : '共 ${teammates.profiles.length} 人 · 今日领先 ${leader.profile.nickname} +${leader.record.totalDelta}',
          style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
