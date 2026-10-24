import 'package:flutter/material.dart';
import '../../models/contest_record.dart';
import '../shared/workspace_entry_card.dart';

class ContestsEntryPanel extends StatelessWidget {
  const ContestsEntryPanel(
      {super.key, required this.contests, required this.onOpen});
  final List<ContestRecord> contests;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final bestRank = contests.isEmpty
        ? null
        : contests.map((c) => c.rank).reduce((a, b) => a < b ? a : b);
    return WorkspaceEntryCard(
      title: '训练赛',
      icon: Icons.emoji_events_outlined,
      description: '记录通过数、排名变化和赛后复盘。',
      onOpen: onOpen,
      openKey: const ValueKey('contests-entry-button'),
      child: Text(
          contests.isEmpty
              ? '还没有比赛记录'
              : '共 ${contests.length} 场 · 最近 #${contests.first.rank} · 最好 #$bestRank',
          style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
