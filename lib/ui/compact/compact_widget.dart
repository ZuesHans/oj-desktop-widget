import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/solved_totals.dart';
import '../../models/oj_state.dart';

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
      child: Container(
        padding: const EdgeInsets.all(8),
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xEAF9FBF8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x66FFFFFF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CompactStatLine(
                        label: 'AC',
                        value: '$totalSolved',
                        isPrimary: true,
                      ),
                      const SizedBox(height: 6),
                      _CompactStatLine(
                        label: 'Today',
                        value: '+$today',
                        isPrimary: false,
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CompactIconButton(
                      key: const ValueKey('compact-refresh-button'),
                      tooltip: 'Refresh',
                      onPressed: onRefresh,
                      child: refreshing
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh, size: 18),
                    ),
                    const SizedBox(height: 4),
                    _CompactIconButton(
                      key: const ValueKey('open-dashboard-button'),
                      tooltip: 'Open dashboard',
                      onPressed: onOpenDashboard,
                      child: const Icon(Icons.open_in_full, size: 18),
                    ),
                    const SizedBox(height: 4),
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
          ),
        ),
      ),
    );
  }
}

class _CompactStatLine extends StatelessWidget {
  const _CompactStatLine({
    required this.label,
    required this.value,
    required this.isPrimary,
  });

  final String label;
  final String value;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 46,
          child: Text(
            label,
            style: TextStyle(
              color: const Color(0xFF42655C),
              fontSize: isPrimary ? 12 : 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF10231E),
              fontSize: isPrimary ? 30 : 18,
              fontWeight: isPrimary ? FontWeight.w900 : FontWeight.w800,
              height: 1,
            ),
          ),
        ),
      ],
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
          color: const Color(0xFF365F55),
          disabledColor: const Color(0x66365F55),
          onPressed: onPressed,
          icon: child,
        ),
      ),
    );
  }
}
