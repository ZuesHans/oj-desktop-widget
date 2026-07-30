import 'package:flutter/material.dart';

import '../../core/solved_totals.dart';
import '../../core/time.dart';
import '../../models/teammate.dart';
import '../app_theme.dart';
import '../shared/app_surface_card.dart';
import '../shared/pill.dart';
import 'teammate_editor.dart';

class TeammatesPage extends StatelessWidget {
  const TeammatesPage({
    super.key,
    required this.data,
    required this.todayRanking,
    required this.recentRankings,
    required this.refreshing,
    required this.onBack,
    required this.onSave,
    required this.onDelete,
    required this.onRefreshAll,
    required this.onRefreshOne,
    this.showBackButton = true,
  });

  final TeammateStoreData data;
  final List<TeammateRankEntry> todayRanking;
  final List<TeammateDailyRanking> recentRankings;
  final bool refreshing;
  final VoidCallback onBack;
  final Future<void> Function(TeammateProfile teammate) onSave;
  final Future<void> Function(String id) onDelete;
  final Future<void> Function() onRefreshAll;
  final Future<void> Function(String id) onRefreshOne;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final canAdd = data.profiles.length < maxTeammates;
    return Scaffold(
      backgroundColor: appSurfaceColor,
      body: Container(
        key: const ValueKey('teammates-page'),
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
                        key: const ValueKey('teammates-back-button'),
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
                      child: Icon(Icons.groups_2_outlined, color: accentColor),
                    ),
                    const SizedBox(width: appSpace3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '队友观察',
                            style: TextStyle(
                              color: textPrimaryColor,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '训练日统计 · ${data.profiles.length}/$maxTeammates 人',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: textSecondaryColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: appSpace2),
                    IconButton(
                      key: const ValueKey('refresh-teammates-button'),
                      tooltip: '刷新队友',
                      onPressed: refreshing ? null : () => _refreshAll(context),
                      icon: refreshing
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                    ),
                    const SizedBox(width: appSpace2),
                    FilledButton.icon(
                      key: const ValueKey('add-teammate-button'),
                      onPressed: canAdd ? () => _openEditor(context) : null,
                      icon: const Icon(Icons.add),
                      label: const Text('添加'),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  _TrainingDayNote(
                    trainingDate: trainingDateFor(DateTime.now()),
                    count: data.profiles.length,
                  ),
                  if (!canAdd) ...[
                    const SizedBox(height: 8),
                    Text(
                      '最多添加 3 名队友',
                      style: TextStyle(color: textSecondaryColor),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _TeammateList(
                    data: data,
                    refreshing: refreshing,
                    onEdit: (profile) => _openEditor(context, initial: profile),
                    onDelete: (profile) => _delete(context, profile),
                    onRefresh: (profile) => _refreshOne(context, profile),
                  ),
                  const SizedBox(height: 10),
                  _RankingCard(
                    title: '今日新增排行',
                    emptyText: data.profiles.isEmpty ? '先添加队友' : '刷新后生成今日记录',
                    entries: todayRanking,
                  ),
                  const SizedBox(height: 10),
                  _RecentRankingCard(rankings: recentRankings),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context, {
    TeammateProfile? initial,
  }) async {
    final saved = await showDialog<TeammateProfile>(
      context: context,
      builder: (_) => TeammateEditorDialog(initial: initial),
    );
    if (saved == null) {
      return;
    }
    try {
      await onSave(saved);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(initial == null ? '队友已添加' : '队友已保存')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：${normalizeError(error)}')),
      );
    }
  }

  Future<void> _delete(BuildContext context, TeammateProfile profile) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('删除队友？'),
            content: Text('确认删除「${profile.nickname}」及其本地历史记录？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    await onDelete(profile.id);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${profile.nickname} 已删除')),
    );
  }

  Future<void> _refreshAll(BuildContext context) async {
    try {
      await onRefreshAll();
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('队友数据已刷新')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('刷新失败：${normalizeError(error)}')),
      );
    }
  }

  Future<void> _refreshOne(
    BuildContext context,
    TeammateProfile profile,
  ) async {
    try {
      await onRefreshOne(profile.id);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${profile.nickname} 已刷新')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('刷新失败：${normalizeError(error)}')),
      );
    }
  }
}

class _TrainingDayNote extends StatelessWidget {
  const _TrainingDayNote({
    required this.trainingDate,
    required this.count,
  });

  final String trainingDate;
  final int count;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(appSpace3),
      child: Row(
        children: [
          Icon(Icons.schedule, color: accentColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '训练日 $trainingDate · 今日统计从 04:00 开始',
              style: TextStyle(
                color: textPrimaryColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Pill(label: '$count/$maxTeammates'),
        ],
      ),
    );
  }
}

class _TeammateList extends StatelessWidget {
  const _TeammateList({
    required this.data,
    required this.refreshing,
    required this.onEdit,
    required this.onDelete,
    required this.onRefresh,
  });

  final TeammateStoreData data;
  final bool refreshing;
  final void Function(TeammateProfile profile) onEdit;
  final void Function(TeammateProfile profile) onDelete;
  final void Function(TeammateProfile profile) onRefresh;

  @override
  Widget build(BuildContext context) {
    if (data.profiles.isEmpty) {
      return const AppEmptyState(
        icon: Icons.groups_2_outlined,
        title: '还没有队友',
        message: '还没有队友，先添加一个公开账号吧。',
      );
    }
    final today = trainingDateFor(DateTime.now());
    return Column(
      children: [
        for (final profile in data.profiles)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _TeammateCard(
              profile: profile,
              record: _recordFor(data.records, profile.id, today),
              refreshing: refreshing,
              onEdit: () => onEdit(profile),
              onDelete: () => onDelete(profile),
              onRefresh: () => onRefresh(profile),
            ),
          ),
      ],
    );
  }
}

class _TeammateCard extends StatelessWidget {
  const _TeammateCard({
    required this.profile,
    required this.record,
    required this.refreshing,
    required this.onEdit,
    required this.onDelete,
    required this.onRefresh,
  });

  final TeammateProfile profile;
  final TeammateDailyRecord? record;
  final bool refreshing;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final errors = record?.errors ?? const <String, String>{};
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  profile.nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _DeltaChip(delta: record?.totalDelta ?? 0),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            profile.accounts
                .where((account) => account.enabled)
                .map((account) =>
                    '${teammatePlatformName(account.platform)}: ${account.handle}')
                .join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: textSecondaryColor, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            record?.refreshedAt == null
                ? '尚未刷新'
                : '最近刷新 ${formatTime(record!.refreshedAt)}',
            style: TextStyle(color: textSecondaryColor, fontSize: 12),
          ),
          if (errors.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in errors.entries)
                  Pill(label: '${teammatePlatformName(entry.key)} 失败'),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                key: ValueKey('refresh-teammate-${profile.id}'),
                tooltip: '刷新',
                onPressed: refreshing ? null : onRefresh,
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                key: ValueKey('edit-teammate-${profile.id}'),
                tooltip: '编辑',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                key: ValueKey('delete-teammate-${profile.id}'),
                tooltip: '删除',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RankingCard extends StatelessWidget {
  const _RankingCard({
    required this.title,
    required this.emptyText,
    required this.entries,
  });

  final String title;
  final String emptyText;
  final List<TeammateRankEntry> entries;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(appSpace3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: textPrimaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            SizedBox(
              height: 64,
              child: Center(
                child: Text(
                  emptyText,
                  style: TextStyle(color: textSecondaryColor),
                ),
              ),
            )
          else
            ...entries.indexed.map((item) {
              final (index, entry) = item;
              return _RankRow(
                rank: index + 1,
                entry: entry,
                maxDelta: entries.first.record.totalDelta,
              );
            }),
        ],
      ),
    );
  }
}

class _RecentRankingCard extends StatelessWidget {
  const _RecentRankingCard({required this.rankings});

  final List<TeammateDailyRanking> rankings;

  @override
  Widget build(BuildContext context) {
    final hasRecords = rankings.any((ranking) => ranking.entries.isNotEmpty);
    return AppSurfaceCard(
      padding: const EdgeInsets.all(appSpace3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '最近 7 天排行',
            style: TextStyle(
              color: textPrimaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (!hasRecords)
            SizedBox(
              height: 64,
              child: Center(
                child: Text(
                  '刷新后生成记录',
                  style: TextStyle(color: textSecondaryColor),
                ),
              ),
            )
          else
            ...rankings.map((ranking) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DailyRankingGroup(ranking: ranking),
              );
            }),
        ],
      ),
    );
  }
}

class _DailyRankingGroup extends StatelessWidget {
  const _DailyRankingGroup({required this.ranking});

  final TeammateDailyRanking ranking;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cardMutedColor,
        borderRadius: BorderRadius.circular(appRadiusControl),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ranking.trainingDate,
              style: TextStyle(
                color: textPrimaryColor,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            if (ranking.entries.isEmpty)
              Text(
                '无记录',
                style: TextStyle(color: textSecondaryColor, fontSize: 12),
              )
            else
              ...ranking.entries.indexed.map((item) {
                final (index, entry) = item;
                return _RankRow(
                  rank: index + 1,
                  entry: entry,
                  maxDelta: ranking.entries.first.record.totalDelta,
                  dense: true,
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.entry,
    required this.maxDelta,
    this.dense = false,
  });

  final int rank;
  final TeammateRankEntry entry;
  final int maxDelta;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final widthFactor =
        maxDelta <= 0 ? 0.06 : entry.record.totalDelta / maxDelta;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 3 : 5),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#$rank',
              style: TextStyle(
                color: textSecondaryColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              entry.profile.nickname,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textPrimaryColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: widthFactor.clamp(0.06, 1).toDouble(),
                color: accentColor,
                backgroundColor: borderColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text(
              '+${entry.record.totalDelta}',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: textPrimaryColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.delta});

  final int delta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(appRadiusPill),
        border: Border.all(color: accentColor.withValues(alpha: 0.22)),
      ),
      child: Text(
        '今日 +$delta',
        style: TextStyle(
          color: accentColor,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

TeammateDailyRecord? _recordFor(
  List<TeammateDailyRecord> records,
  String teammateId,
  String trainingDate,
) {
  for (final record in records) {
    if (record.teammateId == teammateId &&
        record.trainingDate == trainingDate) {
      return record;
    }
  }
  return null;
}
