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
  });

  final HomeSummaryViewModel viewModel;
  final ValueChanged<HomeActionTarget> onOpenAction;
  final VoidCallback onOpenSettings;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('home-summary-panel'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSurfaceCard(
          key: const ValueKey('home-progress-card'),
          color: cardMutedColor,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(appRadiusControl),
                    ),
                    child: Icon(
                      Icons.bolt_outlined,
                      color: accentColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '今日训练',
                      style: TextStyle(
                        color: textPrimaryColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: appSpace2),
                  Flexible(
                    child: Tooltip(
                      message: viewModel.syncLabel,
                      child: Pill(label: viewModel.syncLabel),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${viewModel.totalSolved}',
                    style: TextStyle(
                      color: textPrimaryColor,
                      fontSize: 46,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Pill(label: '今日 +${viewModel.todayDelta}'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                viewModel.enabledAccountCount == 0
                    ? '配置账号后，这里会汇总你的 OJ 通过数。'
                    : '${viewModel.enabledAccountCount} 个账号，${viewModel.platformCount} 个平台正在跟踪。',
                style: TextStyle(color: textSecondaryColor),
              ),
            ],
          ),
        ),
        if (viewModel.emptyMessage != null) ...[
          const SizedBox(height: 12),
          AppEmptyState(
            key: const ValueKey('home-empty-account-state'),
            icon: Icons.account_circle_outlined,
            title: '先连接一个账号',
            message: viewModel.emptyMessage!,
            action: OutlinedButton.icon(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.tune),
              label: const Text('打开设置'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          '需要处理',
          style: TextStyle(
            color: textPrimaryColor,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 620;
            return GridView.count(
              key: const ValueKey('home-status-grid'),
              crossAxisCount: wide ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: wide ? 1.45 : 1.55,
              children: [
                for (final card in viewModel.statusCards)
                  _StatusTile(card: card),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                '常用入口',
                style: TextStyle(
                  color: textPrimaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('刷新'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 620;
            return GridView.count(
              key: const ValueKey('home-action-grid'),
              crossAxisCount: wide ? 3 : 1,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: wide ? 2.45 : 4.2,
              children: [
                for (final action in viewModel.actionCards)
                  _ActionTile(
                    action: action,
                    onTap: () => onOpenAction(action.target),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.card});

  final HomeStatusCard card;

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(card.tone);
    return AppSurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_toneIcon(card.tone), size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  card.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textSecondaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            card.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            card.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: textSecondaryColor, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.action,
    required this.onTap,
  });

  final HomeActionCard action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      key: ValueKey('home-action-${action.target.name}'),
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_actionIcon(action.target), color: accentColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  action.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: textSecondaryColor, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            action.metric,
            style: TextStyle(
              color: textPrimaryColor,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

Color _toneColor(HomeCardTone tone) {
  return switch (tone) {
    HomeCardTone.good => accentColor,
    HomeCardTone.neutral => textPrimaryColor,
    HomeCardTone.warning => dangerColor,
    HomeCardTone.info => Colors.blueGrey,
  };
}

IconData _toneIcon(HomeCardTone tone) {
  return switch (tone) {
    HomeCardTone.good => Icons.check_circle_outline,
    HomeCardTone.neutral => Icons.info_outline,
    HomeCardTone.warning => Icons.error_outline,
    HomeCardTone.info => Icons.sync,
  };
}

IconData _actionIcon(HomeActionTarget target) {
  return switch (target) {
    HomeActionTarget.heatmap => Icons.calendar_view_week,
    HomeActionTarget.problems => Icons.bookmark_border,
    HomeActionTarget.refreshLogs => Icons.history,
    HomeActionTarget.contests => Icons.emoji_events_outlined,
    HomeActionTarget.teammates => Icons.groups_2_outlined,
  };
}
