import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/solved_totals.dart';
import '../../models/contest_record.dart';
import '../app_theme.dart';
import '../shared/app_surface_card.dart';
import '../shared/pill.dart';
import 'contest_editor.dart';

class ContestsPage extends StatelessWidget {
  const ContestsPage({
    super.key,
    required this.contests,
    required this.rankPoints,
    required this.onBack,
    required this.onSave,
    required this.onDelete,
    this.showBackButton = true,
  });

  final List<ContestRecord> contests;
  final List<ContestRankPoint> rankPoints;
  final VoidCallback onBack;
  final Future<void> Function(ContestRecord contest) onSave;
  final Future<void> Function(String id) onDelete;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final bestRank = contests.isEmpty
        ? null
        : contests.map((contest) => contest.rank).reduce(math.min);
    final averageRank = contests.isEmpty
        ? null
        : contests.map((contest) => contest.rank).reduce((a, b) => a + b) /
            contests.length;
    final latest = contests.isEmpty ? null : contests.first;

    return Scaffold(
      backgroundColor: appSurfaceColor,
      body: Container(
        key: const ValueKey('contests-page'),
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
                        key: const ValueKey('contests-back-button'),
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
                      child:
                          Icon(Icons.emoji_events_outlined, color: accentColor),
                    ),
                    const SizedBox(width: appSpace3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '比赛记录',
                            style: TextStyle(
                              color: textPrimaryColor,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            contests.isEmpty
                                ? '记录训练赛、校内赛和模拟赛排名'
                                : '共 ${contests.length} 场 · 最近 #${latest!.rank}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: textSecondaryColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: appSpace2),
                    FilledButton.icon(
                      key: const ValueKey('add-contest-button'),
                      onPressed: () => _openEditor(context),
                      icon: const Icon(Icons.add),
                      label: const Text('新增'),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  _ContestSummary(
                    total: contests.length,
                    latestRank: latest?.rank,
                    bestRank: bestRank,
                    averageRank: averageRank,
                  ),
                  const SizedBox(height: 10),
                  _RankChartCard(points: rankPoints),
                  const SizedBox(height: 10),
                  if (contests.isEmpty)
                    const _EmptyContestList()
                  else
                    ...contests.map(
                      (contest) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ContestListItem(
                          contest: contest,
                          onEdit: () => _openEditor(context, contest: contest),
                          onDelete: () => _delete(context, contest),
                        ),
                      ),
                    ),
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
    ContestRecord? contest,
  }) async {
    final saved = await showDialog<ContestRecord>(
      context: context,
      builder: (_) => ContestEditorDialog(initial: contest),
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
        SnackBar(content: Text(contest == null ? '比赛记录已新增' : '比赛记录已保存')),
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

  Future<void> _delete(BuildContext context, ContestRecord contest) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('删除比赛记录？'),
            content: Text('确认删除「${contest.title}」？此操作无法撤销。'),
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
    await onDelete(contest.id);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${contest.title} 已删除')),
    );
  }
}

class _ContestSummary extends StatelessWidget {
  const _ContestSummary({
    required this.total,
    required this.latestRank,
    required this.bestRank,
    required this.averageRank,
  });

  final int total;
  final int? latestRank;
  final int? bestRank;
  final double? averageRank;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(appSpace3),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth >= 520
              ? (constraints.maxWidth - 24) / 4
              : (constraints.maxWidth - 8) / 2;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryTile(label: '总场数', value: '$total', width: width),
              _SummaryTile(
                label: '最近排名',
                value: latestRank == null ? '-' : '#$latestRank',
                width: width,
              ),
              _SummaryTile(
                label: '最好排名',
                value: bestRank == null ? '-' : '#$bestRank',
                width: width,
              ),
              _SummaryTile(
                label: '平均排名',
                value:
                    averageRank == null ? '-' : averageRank!.toStringAsFixed(1),
                width: width,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.width,
  });

  final String label;
  final String value;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cardMutedColor,
          borderRadius: BorderRadius.circular(appRadiusControl),
          border: Border.all(color: borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: textSecondaryColor,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textPrimaryColor,
                  fontSize: 18,
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

class _RankChartCard extends StatefulWidget {
  const _RankChartCard({required this.points});

  final List<ContestRankPoint> points;

  @override
  State<_RankChartCard> createState() => _RankChartCardState();
}

class _RankChartCardState extends State<_RankChartCard> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final selected = _selectedIndex == null ||
            _selectedIndex! < 0 ||
            _selectedIndex! >= widget.points.length
        ? null
        : widget.points[_selectedIndex!];
    return AppSurfaceCard(
      padding: const EdgeInsets.all(appSpace3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '排名曲线',
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                '排名越低越好',
                style: TextStyle(color: textSecondaryColor, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (widget.points.length < 2)
            SizedBox(
              height: 180,
              child: Center(
                child: Text(
                  '至少记录 2 场比赛后显示排名趋势。',
                  style: TextStyle(color: textSecondaryColor),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                return MouseRegion(
                  onHover: (event) {
                    final index = _nearestPointIndex(
                      event.localPosition,
                      Size(constraints.maxWidth, 200),
                      widget.points,
                    );
                    if (index != _selectedIndex) {
                      setState(() => _selectedIndex = index);
                    }
                  },
                  onExit: (_) => setState(() => _selectedIndex = null),
                  child: GestureDetector(
                    onTapDown: (details) {
                      setState(() {
                        _selectedIndex = _nearestPointIndex(
                          details.localPosition,
                          Size(constraints.maxWidth, 200),
                          widget.points,
                        );
                      });
                    },
                    child: SizedBox(
                      height: 200,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: _RankChartPainter(
                          points: widget.points,
                          selectedIndex: _selectedIndex,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          if (selected != null) ...[
            const SizedBox(height: 8),
            _SelectedContest(point: selected),
          ],
        ],
      ),
    );
  }
}

class _SelectedContest extends StatelessWidget {
  const _SelectedContest({required this.point});

  final ContestRankPoint point;

  @override
  Widget build(BuildContext context) {
    final record = point.record;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardMutedColor,
        borderRadius: BorderRadius.circular(appRadiusControl),
        border: Border.all(color: borderColor),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            record.title,
            style: TextStyle(
              color: textPrimaryColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          Pill(label: record.date),
          Pill(label: '#${record.rank}'),
          if (record.totalParticipants != null)
            Pill(label: '/ ${record.totalParticipants} 人'),
          if (record.solvedCount != null)
            Pill(label: '${record.solvedCount} 题'),
        ],
      ),
    );
  }
}

class _ContestListItem extends StatelessWidget {
  const _ContestListItem({
    required this.contest,
    required this.onEdit,
    required this.onDelete,
  });

  final ContestRecord contest;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  contest.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _RankChip(rank: contest.rank),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Pill(label: contest.date),
              if (contest.totalParticipants != null)
                Pill(label: '共 ${contest.totalParticipants} 人'),
              if (contest.solvedCount != null)
                Pill(label: '${contest.solvedCount} 题'),
              if (contest.penalty != null) Pill(label: '罚时 ${contest.penalty}'),
            ],
          ),
          if (contest.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              contest.note,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: textPrimaryColor),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                key: ValueKey('edit-contest-${contest.id}'),
                tooltip: '编辑',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                key: ValueKey('delete-contest-${contest.id}'),
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

class _RankChip extends StatelessWidget {
  const _RankChip({required this.rank});

  final int rank;

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
        '#$rank',
        style: TextStyle(
          color: accentColor,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyContestList extends StatelessWidget {
  const _EmptyContestList();

  @override
  Widget build(BuildContext context) {
    return const AppEmptyState(
      icon: Icons.emoji_events_outlined,
      title: '还没有比赛记录',
      message: '先新增一场训练赛，排名曲线会在至少 2 场后显示。',
    );
  }
}

class _RankChartPainter extends CustomPainter {
  const _RankChartPainter({
    required this.points,
    required this.selectedIndex,
  });

  final List<ContestRankPoint> points;
  final int? selectedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = _chartRect(size);
    final ranks = points.map((point) => point.rank).toList();
    final minRank = ranks.reduce(math.min);
    final maxRank = ranks.reduce(math.max);
    final pointOffsets = _pointOffsets(size, points);

    final gridPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = textSecondaryColor.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    final linePaint = Paint()
      ..color = accentColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;
    final pointPaint = Paint()
      ..color = cardColor
      ..style = PaintingStyle.fill;
    final pointBorderPaint = Paint()
      ..color = accentColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < 4; i++) {
      final y = chart.top + chart.height * i / 3;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }
    canvas.drawLine(chart.bottomLeft, chart.bottomRight, axisPaint);
    canvas.drawLine(chart.topLeft, chart.bottomLeft, axisPaint);

    final path = Path()..moveTo(pointOffsets.first.dx, pointOffsets.first.dy);
    for (final offset in pointOffsets.skip(1)) {
      path.lineTo(offset.dx, offset.dy);
    }
    canvas.drawPath(path, linePaint);

    final areaPath = Path.from(path)
      ..lineTo(pointOffsets.last.dx, chart.bottom)
      ..lineTo(pointOffsets.first.dx, chart.bottom)
      ..close();
    canvas.drawPath(areaPath, fillPaint);

    for (var i = 0; i < pointOffsets.length; i++) {
      final radius = i == selectedIndex ? 5.5 : 4.5;
      canvas.drawCircle(pointOffsets[i], radius, pointPaint);
      canvas.drawCircle(pointOffsets[i], radius, pointBorderPaint);
    }

    _drawLabel(canvas, '#$minRank', Offset(4, chart.top - 6),
        alignRight: false);
    _drawLabel(
      canvas,
      '#$maxRank',
      Offset(4, chart.bottom - 12),
      alignRight: false,
    );
    _drawDateLabel(canvas, points.first.record.date, chart.bottomLeft);
    _drawDateLabel(
      canvas,
      points.last.record.date,
      Offset(chart.right, chart.bottom),
      alignRight: true,
    );
  }

  @override
  bool shouldRepaint(covariant _RankChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}

Rect _chartRect(Size size) {
  return Rect.fromLTWH(42, 12, math.max(1, size.width - 56), size.height - 40);
}

List<Offset> _pointOffsets(Size size, List<ContestRankPoint> points) {
  final chart = _chartRect(size);
  final ranks = points.map((point) => point.rank).toList();
  final minRank = ranks.reduce(math.min);
  final maxRank = ranks.reduce(math.max);
  final firstDate = points.first.date;
  final lastDate = points.last.date;
  final daySpan = lastDate.difference(firstDate).inDays;
  final hasDateSpan = daySpan > 0;
  final totalDays = math.max(1, daySpan);
  final rankSpan = math.max(1, maxRank - minRank);

  return [
    for (var i = 0; i < points.length; i++)
      Offset(
        hasDateSpan
            ? chart.left +
                chart.width *
                    points[i].date.difference(firstDate).inDays /
                    totalDays
            : chart.left + chart.width * i / math.max(1, points.length - 1),
        chart.top + chart.height * (points[i].rank - minRank) / rankSpan,
      ),
  ];
}

int? _nearestPointIndex(
  Offset position,
  Size size,
  List<ContestRankPoint> points,
) {
  if (points.length < 2) {
    return null;
  }
  final offsets = _pointOffsets(size, points);
  var nearestIndex = 0;
  var nearestDistance = double.infinity;
  for (var i = 0; i < offsets.length; i++) {
    final distance = (offsets[i] - position).distance;
    if (distance < nearestDistance) {
      nearestIndex = i;
      nearestDistance = distance;
    }
  }
  return nearestDistance <= 36 ? nearestIndex : null;
}

void _drawLabel(
  Canvas canvas,
  String text,
  Offset offset, {
  bool alignRight = false,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(color: textSecondaryColor, fontSize: 10),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(
    canvas,
    Offset(alignRight ? offset.dx - painter.width : offset.dx, offset.dy),
  );
}

void _drawDateLabel(
  Canvas canvas,
  String text,
  Offset offset, {
  bool alignRight = false,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text.substring(5),
      style: TextStyle(color: textSecondaryColor, fontSize: 10),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(
    canvas,
    Offset(
      alignRight ? offset.dx - painter.width : offset.dx,
      offset.dy + 7,
    ),
  );
}
