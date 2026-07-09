import 'package:flutter/material.dart';

import '../app_theme.dart';

class WindowHeader extends StatelessWidget {
  const WindowHeader({
    super.key,
    required this.refreshing,
    required this.onRefresh,
    required this.onSettings,
    required this.onCompact,
    required this.onMinimize,
    required this.onExit,
    this.onStartDrag,
  });

  final bool refreshing;
  final VoidCallback? onRefresh;
  final VoidCallback onSettings;
  final VoidCallback onCompact;
  final VoidCallback onMinimize;
  final VoidCallback onExit;
  final VoidCallback? onStartDrag;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: onStartDrag == null ? null : (_) => onStartDrag!(),
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: cardColor,
          border: Border(bottom: BorderSide(color: borderColor)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(appRadiusControl),
              ),
              child: Icon(
                Icons.bubble_chart_outlined,
                color: accentColor,
                size: 19,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OJ Float',
                    style: TextStyle(
                      color: textPrimaryColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '刷题统计与训练复盘',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textSecondaryColor, fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '刷新',
              onPressed: onRefresh,
              icon: refreshing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: '设置',
              onPressed: onSettings,
              icon: const Icon(Icons.tune),
            ),
            IconButton(
              key: const ValueKey('compact-mode-button'),
              tooltip: '缩小窗口',
              onPressed: onCompact,
              icon: const Icon(Icons.close_fullscreen),
            ),
            IconButton(
              tooltip: '最小化',
              onPressed: onMinimize,
              icon: const Icon(Icons.remove),
            ),
            IconButton(
              key: const ValueKey('dashboard-exit-button'),
              tooltip: '退出程序',
              onPressed: onExit,
              icon: const Icon(Icons.power_settings_new),
            ),
          ],
        ),
      ),
    );
  }
}
