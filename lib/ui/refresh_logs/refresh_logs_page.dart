import 'package:flutter/material.dart';

import '../../core/oj_catalog.dart';
import '../../core/time.dart';
import '../../models/refresh_log_entry.dart';
import '../app_theme.dart';
import '../shared/pill.dart';

class RefreshLogsPage extends StatelessWidget {
  const RefreshLogsPage({
    super.key,
    required this.logs,
    required this.onBack,
  });

  final List<RefreshLogEntry> logs;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appSurfaceColor,
      body: Container(
        key: const ValueKey('refresh-logs-page'),
        color: appSurfaceColor,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    key: const ValueKey('refresh-logs-back-button'),
                    tooltip: '返回',
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      '刷新日志',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Pill(label: '最近 ${logs.length} 条'),
                ],
              ),
            ),
            Expanded(
              child: logs.isEmpty
                  ? const Center(
                      child: Text(
                        '暂无刷新记录',
                        style: TextStyle(color: textSecondaryColor),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: logs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) =>
                          _RefreshLogCard(log: logs[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RefreshLogCard extends StatelessWidget {
  const _RefreshLogCard({required this.log});

  final RefreshLogEntry log;

  @override
  Widget build(BuildContext context) {
    final color = switch (log.status) {
      RefreshLogStatus.success => accentColor,
      RefreshLogStatus.fallbackSuccess => Colors.blueGrey,
      RefreshLogStatus.blocked => Colors.orange.shade800,
      RefreshLogStatus.failure => dangerColor,
    };
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
              Expanded(
                child: Text(
                  '${_ojName(log.ojId)} / ${log.username}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: textPrimaryColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _StatusPill(label: _statusLabel(log.status), color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${dateKey(log.fetchedAt)} ${formatTime(log.fetchedAt)} · ${log.source}',
            style: const TextStyle(color: textSecondaryColor, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            _countText(log),
            style: const TextStyle(color: textSecondaryColor, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            log.message,
            style: const TextStyle(color: textPrimaryColor),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

String _ojName(String ojId) {
  for (final meta in supportedOjs) {
    if (meta.id == ojId) {
      return meta.name;
    }
  }
  return ojId;
}

String _statusLabel(RefreshLogStatus status) {
  return switch (status) {
    RefreshLogStatus.success => '成功',
    RefreshLogStatus.fallbackSuccess => '备用成功',
    RefreshLogStatus.blocked => '已拦截',
    RefreshLogStatus.failure => '失败',
  };
}

String _countText(RefreshLogEntry log) {
  final current = log.solvedCount == null ? '-' : '${log.solvedCount}';
  final previous =
      log.previousSolvedCount == null ? '-' : '${log.previousSolvedCount}';
  return '本次 $current · 历史 $previous';
}
