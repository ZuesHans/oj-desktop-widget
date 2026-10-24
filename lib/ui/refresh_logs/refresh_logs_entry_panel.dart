import 'package:flutter/material.dart';
import '../../models/refresh_log_entry.dart';
import '../shared/workspace_entry_card.dart';

class RefreshLogsEntryPanel extends StatelessWidget {
  const RefreshLogsEntryPanel(
      {super.key, required this.logs, required this.onOpen});
  final List<RefreshLogEntry> logs;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final failures =
        logs.where((log) => log.status == RefreshLogStatus.failure).length;
    final blocked =
        logs.where((log) => log.status == RefreshLogStatus.blocked).length;
    return WorkspaceEntryCard(
      title: '刷新日志',
      icon: Icons.history,
      description: '保留每次抓取的结果、原因与时间。',
      onOpen: onOpen,
      openKey: const ValueKey('refresh-logs-entry-button'),
      child: Text(
          logs.isEmpty
              ? '暂无刷新记录'
              : '拦截 $blocked · 失败 $failures · ${logs.first.message}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
