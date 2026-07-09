import 'package:flutter/material.dart';

import '../../core/oj_catalog.dart';
import '../../core/time.dart';
import '../../models/refresh_log_entry.dart';
import '../app_theme.dart';
import '../shared/app_surface_card.dart';
import '../shared/pill.dart';

class RefreshLogsPage extends StatelessWidget {
  const RefreshLogsPage({
    super.key,
    required this.logs,
    required this.onBack,
    this.showBackButton = true,
  });

  final List<RefreshLogEntry> logs;
  final VoidCallback onBack;
  final bool showBackButton;

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
              padding: const EdgeInsets.fromLTRB(
                  appSpace4, 10, appSpace4, appSpace2),
              child: AppSurfaceCard(
                child: Row(
                  children: [
                    if (showBackButton) ...[
                      IconButton(
                        key: const ValueKey('refresh-logs-back-button'),
                        tooltip: '返回',
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: appSpace1),
                    ],
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(appRadiusControl),
                        border: Border.all(
                            color: accentColor.withValues(alpha: 0.2)),
                      ),
                      child:
                          Icon(Icons.fact_check_outlined, color: accentColor),
                    ),
                    const SizedBox(width: appSpace3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '刷新日志',
                            style: TextStyle(
                              color: textPrimaryColor,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            logs.isEmpty ? '还没有刷新记录' : '保留最近刷新、备用和失败状态',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: textSecondaryColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: appSpace2),
                    Pill(label: '最近 ${logs.length} 条'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: logs.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.fromLTRB(
                        appSpace4,
                        0,
                        appSpace4,
                        appSpace4,
                      ),
                      child: Center(
                        child: AppEmptyState(
                          icon: Icons.fact_check_outlined,
                          title: '暂无刷新记录',
                          message: '完成一次刷新后，这里会显示来源、状态和数量变化。',
                        ),
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
    return AppSurfaceCard(
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
                  style: TextStyle(
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
            style: TextStyle(color: textSecondaryColor, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            _countText(log),
            style: TextStyle(color: textSecondaryColor, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            log.message,
            style: TextStyle(color: textPrimaryColor),
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
