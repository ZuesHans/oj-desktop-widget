import 'package:flutter/material.dart';

import '../../core/solved_totals.dart';
import '../../core/time.dart';
import '../../models/teammate.dart';
import '../app_theme.dart';
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
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    key: const ValueKey('teammates-back-button'),
                    tooltip: '返回',
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      '队友观察',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
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
                  const SizedBox(width: 6),
                  FilledButton.icon(
                    key: const ValueKey('add-teammate-button'),
                    onPressed: canAdd ? () => _openEditor(context) : null,
                    icon: const Icon(Icons.add),
                    label: const Text('添加'),
                  ),
                ],
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
                    const Text(
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, color: accentColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '训练日 $trainingDate · 今日统计从 04:00 开始',
              style: const TextStyle(
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
      return const _EmptyCard(text: '还没有队友，先添加一个公开账号吧。');
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
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
                  style: const TextStyle(
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
            style: const TextStyle(color: textSecondaryColor, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            record?.refreshedAt == null
                ? '尚未刷新'
                : '最近刷新 ${formatTime(record!.refreshedAt)}',
            style: const TextStyle(color: textSecondaryColor, fontSize: 12),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
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
                  style: const TextStyle(color: textSecondaryColor),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '最近 7 天排行',
            style: TextStyle(
              color: textPrimaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (!hasRecords)
            const SizedBox(
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
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ranking.trainingDate,
              style: const TextStyle(
                color: textPrimaryColor,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            if (ranking.entries.isEmpty)
              const Text(
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
              style: const TextStyle(
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
              style: const TextStyle(
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
              style: const TextStyle(
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
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '今日 +$delta',
        style: const TextStyle(
          color: accentColor,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 112,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        style: const TextStyle(color: textSecondaryColor),
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
