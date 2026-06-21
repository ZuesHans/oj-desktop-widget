import 'package:flutter/material.dart';

import '../../models/refresh_log_entry.dart';
import '../app_theme.dart';

class RefreshLogsEntryPanel extends StatelessWidget {
  const RefreshLogsEntryPanel({
    super.key,
    required this.logs,
    required this.onOpen,
  });

  final List<RefreshLogEntry> logs;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final blocked =
        logs.where((log) => log.status == RefreshLogStatus.blocked).length;
    final failures =
        logs.where((log) => log.status == RefreshLogStatus.failure).length;
    final latest = logs.isEmpty ? '暂无刷新记录' : logs.first.message;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.fact_check_outlined, color: accentColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '刷新日志',
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '拦截 $blocked · 失败 $failures · $latest',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: textSecondaryColor, fontSize: 12),
                ),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            key: const ValueKey('refresh-logs-entry-button'),
            onPressed: onOpen,
            icon: const Icon(Icons.receipt_long, size: 18),
            label: const Text('打开'),
          ),
        ],
      ),
    );
  }
}
