import '../../core/oj_catalog.dart';
import '../../core/solved_totals.dart';
import '../../core/time.dart';
import '../../models/fetch_result.dart';
import '../../models/oj_state.dart';
import '../../models/refresh_log_entry.dart';
import '../../services/sync_service.dart';

class HomeSummaryViewModel {
  const HomeSummaryViewModel({
    required this.totalSolved,
    required this.todayDelta,
    required this.todayDeltaLabel,
    required this.enabledAccountCount,
    required this.platformCount,
    required this.updatedAt,
    required this.statusCards,
    required this.actionCards,
    required this.syncLabel,
    required this.hasAttentionItems,
    required this.emptyMessage,
  });

  factory HomeSummaryViewModel.fromState(
    OjState state, {
    bool refreshing = false,
    bool syncing = false,
    SyncResult? lastSyncResult,
  }) {
    final latestItems = state.latest.values.expand((items) => items).toList();
    final updatedAt = latestItems
        .where((item) => item.fetchedAt != null)
        .map((item) => item.fetchedAt!)
        .fold<DateTime?>(null, (latest, item) {
      if (latest == null || item.isAfter(latest)) {
        return item;
      }
      return latest;
    });
    final enabledAccounts = state.config.accounts.values
        .where((account) => account.enabled && account.usernames.isNotEmpty)
        .fold<int>(0, (sum, account) => sum + account.usernames.length);
    final enabledPlatforms = state.config.accounts.values
        .where((account) => account.enabled && account.usernames.isNotEmpty)
        .length;
    final failures =
        latestItems.where((item) => item.status == FetchStatus.failure).length;
    final blocked = state.refreshLogs
        .where((log) => log.status == RefreshLogStatus.blocked)
        .length;
    final staleLabel =
        updatedAt == null ? '尚未刷新' : '更新 ${formatTime(updatedAt)}';
    final syncLabel = _syncLabel(
      state,
      syncing: syncing,
      lastSyncResult: lastSyncResult,
    );
    final todayDeltaLabel = state.todaySummary.hasUnknown
        ? '未知'
        : state.todaySummary.hasEstimated
            ? '约 +${state.todaySummary.totalDelta}'
            : state.todaySummary.totalDelta > 0
                ? '+${state.todaySummary.totalDelta}'
                : '${state.todaySummary.totalDelta}';

    return HomeSummaryViewModel(
      totalSolved: totalSolvedFromLatest(state.latest),
      todayDelta: state.todaySummary.totalDelta,
      todayDeltaLabel: todayDeltaLabel,
      enabledAccountCount: enabledAccounts,
      platformCount: enabledPlatforms,
      updatedAt: updatedAt,
      statusCards: [
        HomeStatusCard(
          title: '今日进度',
          value: todayDeltaLabel,
          description: state.todaySummary.hasUnknown
              ? '缺少可靠基线，等待下一次刷新'
              : state.todaySummary.hasEstimated
                  ? '部分平台根据累计通过数估算'
                  : state.todaySummary.totalDelta > 0
                      ? '今天已经有新的通过记录'
                      : '今天还没有新增通过',
          tone: state.todaySummary.totalDelta > 0
              ? HomeCardTone.good
              : HomeCardTone.neutral,
        ),
        HomeStatusCard(
          title: '账号状态',
          value: '$enabledAccounts',
          description:
              enabledAccounts == 0 ? '还没有配置启用账号' : '$enabledPlatforms 个平台正在跟踪',
          tone: enabledAccounts == 0 ? HomeCardTone.warning : HomeCardTone.good,
        ),
        HomeStatusCard(
          title: '刷新状态',
          value: refreshing ? '刷新中' : (failures + blocked).toString(),
          description: refreshing
              ? '正在获取最新数据'
              : failures + blocked == 0
                  ? staleLabel
                  : '$failures 个失败，$blocked 个被保护',
          tone: refreshing
              ? HomeCardTone.info
              : failures + blocked == 0
                  ? HomeCardTone.neutral
                  : HomeCardTone.warning,
        ),
        HomeStatusCard(
          title: '同步',
          value: state.config.sync.enabled ? '已开启' : '未开启',
          description: syncLabel,
          tone: state.config.sync.enabled
              ? _syncTone(lastSyncResult, syncing)
              : HomeCardTone.neutral,
        ),
      ],
      actionCards: [
        HomeActionCard(
          title: '今日训练',
          description:
              '${state.training.tasks.where((item) => item.trainingDate == trainingDateFor(DateTime.now())).length} 项任务，按自己的计划开始训练',
          metric:
              '${state.training.tasks.where((item) => item.trainingDate == trainingDateFor(DateTime.now())).length}',
          target: HomeActionTarget.training,
        ),
        HomeActionCard(
          title: '补题清单',
          description: '${state.problems.length} 道题，继续整理训练线索',
          metric: '${state.problems.length}',
          target: HomeActionTarget.problems,
        ),
        HomeActionCard(
          title: '热力图',
          description: '${state.snapshots.length} 条快照，看看最近节奏',
          metric: '${state.snapshots.length}',
          target: HomeActionTarget.heatmap,
        ),
        HomeActionCard(
          title: '刷新日志',
          description: '${state.refreshLogs.length} 条记录，用来排查抓取问题',
          metric: '${state.refreshLogs.length}',
          target: HomeActionTarget.refreshLogs,
        ),
        HomeActionCard(
          title: '训练赛',
          description: '${state.contests.length} 场记录，复盘比赛表现',
          metric: '${state.contests.length}',
          target: HomeActionTarget.contests,
        ),
        HomeActionCard(
          title: '队友观察',
          description: '${state.teammates.profiles.length} 名队友，比较今日训练',
          metric: '${state.teammates.profiles.length}',
          target: HomeActionTarget.teammates,
        ),
      ],
      syncLabel: syncLabel,
      hasAttentionItems: enabledAccounts == 0 || failures > 0 || blocked > 0,
      emptyMessage: enabledAccounts == 0
          ? '先在设置里启用至少一个 OJ 账号，首页就会显示总通过、今日进度和刷新状态。'
          : null,
    );
  }

  final int totalSolved;
  final int todayDelta;
  final String todayDeltaLabel;
  final int enabledAccountCount;
  final int platformCount;
  final DateTime? updatedAt;
  final List<HomeStatusCard> statusCards;
  final List<HomeActionCard> actionCards;
  final String syncLabel;
  final bool hasAttentionItems;
  final String? emptyMessage;

  static String _syncLabel(
    OjState state, {
    required bool syncing,
    required SyncResult? lastSyncResult,
  }) {
    if (!state.config.sync.enabled) {
      return '仅保存在本地';
    }
    if (syncing) {
      return '正在同步';
    }
    if (lastSyncResult == null) {
      return state.config.sync.autoSyncAfterRefresh ? '刷新后自动同步' : '手动同步';
    }
    return switch (lastSyncResult.status) {
      SyncStatus.success => '上次同步成功',
      SyncStatus.skipped => '上次同步跳过：${lastSyncResult.message}',
      SyncStatus.failure => '上次同步失败：${lastSyncResult.message}',
    };
  }

  static HomeCardTone _syncTone(SyncResult? result, bool syncing) {
    if (syncing) {
      return HomeCardTone.info;
    }
    return switch (result?.status) {
      SyncStatus.failure => HomeCardTone.warning,
      SyncStatus.success => HomeCardTone.good,
      SyncStatus.skipped => HomeCardTone.neutral,
      null => HomeCardTone.neutral,
    };
  }
}

class HomeStatusCard {
  const HomeStatusCard({
    required this.title,
    required this.value,
    required this.description,
    required this.tone,
  });

  final String title;
  final String value;
  final String description;
  final HomeCardTone tone;
}

class HomeActionCard {
  const HomeActionCard({
    required this.title,
    required this.description,
    required this.metric,
    required this.target,
  });

  final String title;
  final String description;
  final String metric;
  final HomeActionTarget target;
}

enum HomeActionTarget {
  training,
  heatmap,
  problems,
  refreshLogs,
  contests,
  teammates,
}

enum HomeCardTone { good, neutral, warning, info }

String platformNameForId(String ojId) {
  for (final meta in supportedOjs) {
    if (meta.id == ojId) {
      return meta.name;
    }
  }
  return ojId;
}
