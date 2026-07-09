import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/solved_totals.dart';
import '../../models/oj_state.dart';
import '../app_theme.dart';

class CompactWidget extends StatelessWidget {
  const CompactWidget({
    super.key,
    required this.state,
    required this.refreshing,
    required this.onRefresh,
    required this.onOpenDashboard,
    required this.onExit,
  });

  final OjState state;
  final bool refreshing;
  final VoidCallback? onRefresh;
  final VoidCallback onOpenDashboard;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final totalSolved = totalSolvedFromLatest(state.latest);
    final today = state.todaySummary.totalDelta;

    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      onTap: onOpenDashboard,
      child: DecoratedBox(
        key: const ValueKey('compact-widget'),
        decoration: BoxDecoration(
          color: compactSurfaceColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: compactShadowColor,
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 18, 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '总通过',
                          style: TextStyle(
                            color: compactLabelColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 1),
                        SizedBox(
                          height: 54,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '$totalSolved',
                                maxLines: 1,
                                style: TextStyle(
                                  color: compactTextColor,
                                  fontSize: 52,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      _CompactIconButton(
                        key: const ValueKey('compact-refresh-button'),
                        tooltip: '刷新',
                        onPressed: onRefresh,
                        child: refreshing
                            ? const SizedBox.square(
                                dimension: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh, size: 18),
                      ),
                      const SizedBox(height: 2),
                      _CompactIconButton(
                        key: const ValueKey('open-dashboard-button'),
                        tooltip: '打开浮窗',
                        onPressed: onOpenDashboard,
                        child: const Icon(Icons.open_in_full, size: 18),
                      ),
                      const SizedBox(height: 2),
                      _CompactIconButton(
                        key: const ValueKey('compact-exit-button'),
                        tooltip: '退出程序',
                        onPressed: onExit,
                        child: const Icon(Icons.power_settings_new, size: 18),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                '今日 +$today',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: compactLabelColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactIconButton extends StatelessWidget {
  const _CompactIconButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 30,
        child: IconButton(
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          color: compactLabelColor,
          disabledColor: compactLabelColor.withValues(alpha: 0.38),
          onPressed: onPressed,
          icon: child,
        ),
      ),
    );
  }
}
