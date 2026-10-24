import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../shared/app_surface_card.dart';
import '../shared/pill.dart';
import 'home_summary_view_model.dart';

class HomeSummaryPanel extends StatelessWidget {
  const HomeSummaryPanel(
      {super.key,
      required this.viewModel,
      required this.onOpenAction,
      required this.onOpenSettings,
      required this.onRefresh,
      this.enabledActions = HomeActionTarget.values});

  final HomeSummaryViewModel viewModel;
  final ValueChanged<HomeActionTarget> onOpenAction;
  final VoidCallback onOpenSettings;
  final VoidCallback? onRefresh;
  final List<HomeActionTarget> enabledActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return AppSurfaceCard(
      key: const ValueKey('home-summary-panel'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('累计通过', style: theme.bodySmall),
          const Spacer(),
          Pill(label: viewModel.syncLabel),
        ]),
        const SizedBox(height: 6),
        Row(
            key: const ValueKey('home-progress-card'),
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${viewModel.totalSolved}',
                  style: TextStyle(
                      fontSize: 44,
                      height: 1.15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -1,
                      color: textPrimaryColor)),
              const SizedBox(width: 14),
              Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Pill(
                      label: '今日 ${viewModel.todayDeltaLabel}',
                      color: accentColor)),
              const Spacer(),
              TextButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('刷新数据')),
            ]),
        const SizedBox(height: 10),
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
        const SizedBox(height: 12),
        Divider(height: 1, color: borderColor),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 520 ? 4 : 2;
          final width = (constraints.maxWidth - 16 * (columns - 1)) / columns;
          return Wrap(
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
                            const SizedBox(height: 3),
                            Text(card.value,
                                style: TextStyle(
                                    fontSize: 20,
                                    height: 1.5,
                                    fontWeight: FontWeight.w500,
                                    color: card.tone == HomeCardTone.warning &&
                                            (card.title != '账号状态' ||
                                                viewModel.enabledAccountCount >
                                                    0)
                                        ? dangerColor
                                        : textPrimaryColor)),
                            Text(card.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.bodySmall),
                          ])),
              ]);
        }),
        if (enabledActions.isNotEmpty) ...[
          const SizedBox(height: 16),
          Divider(height: 1, color: borderColor),
          const SizedBox(height: 8),
          Wrap(
              key: const ValueKey('home-action-grid'),
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final action in viewModel.actionCards)
                  if (enabledActions.contains(action.target))
                    TextButton.icon(
                        key: ValueKey('home-action-${action.target.name}'),
                        style: TextButton.styleFrom(
                            foregroundColor: textSecondaryColor),
                        onPressed: () => onOpenAction(action.target),
                        icon: Icon(_actionIcon(action.target), size: 16),
                        label: Text(action.title)),
              ]),
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
