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
    required this.onOpenDashboard,
  });

  final OjState state;
  final bool refreshing;
  final VoidCallback onOpenDashboard;

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
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '总通过',
                    style: TextStyle(
                      color: compactLabelColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (refreshing)
                    const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '$totalSolved',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: compactTextColor,
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
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
