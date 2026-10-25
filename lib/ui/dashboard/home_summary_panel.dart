import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../shared/app_surface_card.dart';
import '../shared/pill.dart';
import 'home_summary_view_model.dart';

class HomeSummaryPanel extends StatelessWidget {
  const HomeSummaryPanel({
    super.key,
    required this.viewModel,
    required this.onOpenAction,
    required this.onOpenSettings,
    required this.onRefresh,
    this.enabledActions = HomeActionTarget.values,
  });

  final HomeSummaryViewModel viewModel;
  final ValueChanged<HomeActionTarget> onOpenAction;
  final VoidCallback onOpenSettings;
  final VoidCallback? onRefresh;
  final List<HomeActionTarget> enabledActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final progress = viewModel.trainingTotal == 0
        ? 0.0
        : (viewModel.trainingCompleted / viewModel.trainingTotal)
            .clamp(0.0, 1.0);
    return AppSurfaceCard(
      key: const ValueKey('home-summary-panel'),
      color: cardMutedColor,
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('累计通过', style: theme.bodySmall),
          const Spacer(),
          Pill(label: viewModel.syncLabel, color: accentColor),
        ]),
        const SizedBox(height: 10),
        Row(
          key: const ValueKey('home-progress-card'),
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('${viewModel.totalSolved}',
                style: TextStyle(
                    fontFamily: appMonoFontFamily,
                    fontSize: 56,
                    height: 0.98,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -2.5,
                    color: textPrimaryColor)),
            const SizedBox(width: 17),
            Pill(label: '今日 ${viewModel.todayDeltaLabel}', color: warningColor),
            const Spacer(),
            TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('刷新数据'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (viewModel.emptyMessage != null)
          Row(key: const ValueKey('home-empty-account-state'), children: [
            Expanded(
                child: Text('连接 OJ 账号后，自动汇总每天的进步。', style: theme.bodySmall)),
            TextButton(onPressed: onOpenSettings, child: const Text('连接账号')),
          ])
        else
          Text(
              '${viewModel.enabledAccountCount} 个账号 · ${viewModel.platformCount} 个平台，积累每一天的进步。',
              style: theme.bodySmall),
        const SizedBox(height: 18),
        ClipRRect(
          borderRadius: BorderRadius.circular(appRadiusPill),
          child: SizedBox(
            height: 7,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: borderColor.withValues(alpha: 0.55),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 18),
          child: Row(children: [
            Text('今日训练进度', style: theme.bodySmall),
            const SizedBox(width: 14),
            Text(
              viewModel.trainingTotal == 0
                  ? '暂无安排'
                  : '${viewModel.trainingCompleted} / ${viewModel.trainingTotal} 项',
              style: TextStyle(
                  color: textSecondaryColor,
                  fontFamily: appMonoFontFamily,
                  fontSize: 12),
            ),
            const Spacer(),
            TextButton(
                onPressed: onRefresh,
                style: TextButton.styleFrom(
                    foregroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(horizontal: 4)),
                child: const Text('刷新数据 ↗')),
          ]),
        ),
        Divider(height: 1, color: borderColor),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 620 ? 4 : 2;
          final width = (constraints.maxWidth - 16 * (columns - 1)) / columns;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Wrap(
              key: const ValueKey('home-status-grid'),
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final card in viewModel.statusCards)
                  SizedBox(
                    width: width,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(card.title, style: theme.bodySmall),
                          const SizedBox(height: 4),
                          Text(card.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontFamily: appMonoFontFamily,
                                  fontSize: 20,
                                  height: 1.35,
                                  fontWeight: FontWeight.w500,
                                  color: card.tone == HomeCardTone.warning
                                      ? warningColor
                                      : card.tone == HomeCardTone.good
                                          ? accentColor
                                          : textPrimaryColor)),
                          Text(card.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.bodySmall),
                        ]),
                  ),
              ],
            ),
          );
        }),
        if (enabledActions.isNotEmpty) ...[
          Divider(height: 1, color: borderColor),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
              key: const ValueKey('home-action-grid'),
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final action in viewModel.actionCards)
                  if (enabledActions.contains(action.target))
                    TextButton.icon(
                      key: ValueKey('home-action-${action.target.name}'),
                      style: TextButton.styleFrom(
                          foregroundColor: textSecondaryColor,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 6)),
                      onPressed: () => onOpenAction(action.target),
                      icon: Icon(_actionIcon(action.target), size: 16),
                      label: Text(action.title),
                    ),
              ],
            ),
          ),
        ],
      ]),
    );
  }
}

IconData _actionIcon(HomeActionTarget target) => switch (target) {
      HomeActionTarget.training => Icons.timer_outlined,
      HomeActionTarget.heatmap => Icons.calendar_view_week,
      HomeActionTarget.problems => Icons.bookmark_border,
      HomeActionTarget.refreshLogs => Icons.history,
      HomeActionTarget.contests => Icons.emoji_events_outlined,
      HomeActionTarget.teammates => Icons.groups_2_outlined,
    };
