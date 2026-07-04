import 'package:flutter/material.dart';

import '../../core/solved_totals.dart';
import '../../models/problem_record.dart';
import '../../services/problem_book_service.dart';
import '../app_theme.dart';
import '../shared/pill.dart';
import 'problem_editor.dart';

class ProblemsPage extends StatefulWidget {
  const ProblemsPage({
    super.key,
    required this.problems,
    required this.onBack,
    required this.onParseLink,
    required this.onSave,
    required this.onDelete,
    required this.onOpenProblem,
    this.showBackButton = true,
  });

  final List<ProblemRecord> problems;
  final VoidCallback onBack;
  final Future<ParsedProblemLink> Function(String url) onParseLink;
  final Future<void> Function(ProblemRecord problem) onSave;
  final Future<void> Function(String id) onDelete;
  final Future<void> Function(ProblemRecord problem) onOpenProblem;
  final bool showBackButton;

  @override
  State<ProblemsPage> createState() => _ProblemsPageState();
}

class _ProblemsPageState extends State<ProblemsPage> {
  final TextEditingController _queryController = TextEditingController();
  ProblemStatus? _statusFilter;
  ProblemPlatform? _platformFilter;
  String? _tagFilter;
  String _query = '';

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = filterProblems(
      widget.problems,
      query: _query,
      status: _statusFilter,
      platform: _platformFilter,
      tag: _tagFilter,
    );
    final tagStats = buildProblemTagStats(
      widget.problems,
      platform: _platformFilter,
    );
    final pending = widget.problems
        .where((problem) => problem.status != ProblemStatus.AC)
        .length;
    final accepted = widget.problems.length - pending;
    final review = widget.problems
        .where((problem) => problem.status == ProblemStatus.REVIEW)
        .length;
    return Scaffold(
      backgroundColor: appSurfaceColor,
      body: Container(
        key: const ValueKey('problems-page'),
        color: appSurfaceColor,
        child: Column(
          children: [
            _ProblemsHeader(
              showBackButton: widget.showBackButton,
              onBack: widget.onBack,
              onAdd: () => _openEditor(context),
              total: widget.problems.length,
              pending: pending,
              accepted: accepted,
              review: review,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Column(
                children: [
                  TextField(
                    key: const ValueKey('problem-search-field'),
                    controller: _queryController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: '搜索标题、链接、标签或笔记',
                      isDense: true,
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<ProblemStatus?>(
                          isExpanded: true,
                          key: const ValueKey('problem-status-filter'),
                          initialValue: _statusFilter,
                          decoration: const InputDecoration(
                            labelText: '状态',
                          ),
                          items: [
                            const DropdownMenuItem<ProblemStatus?>(
                              value: null,
                              child: Text('全部状态'),
                            ),
                            for (final status in ProblemStatus.values)
                              DropdownMenuItem<ProblemStatus?>(
                                value: status,
                                child: Text(problemStatusLabel(status)),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _statusFilter = value),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<ProblemPlatform?>(
                          isExpanded: true,
                          key: const ValueKey('problem-platform-filter'),
                          initialValue: _platformFilter,
                          decoration: const InputDecoration(
                            labelText: '平台',
                          ),
                          items: [
                            const DropdownMenuItem<ProblemPlatform?>(
                              value: null,
                              child: Text('全部平台'),
                            ),
                            for (final platform in ProblemPlatform.values)
                              DropdownMenuItem<ProblemPlatform?>(
                                value: platform,
                                child: Text(problemPlatformLabel(platform)),
                              ),
                          ],
                          onChanged: (value) => setState(() {
                            _platformFilter = value;
                            _tagFilter = null;
                          }),
                        ),
                      ),
                    ],
                  ),
                  if (tagStats.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final stat in tagStats.take(12))
                            _TagStatChip(
                              stat: stat,
                              selected: stat.tag.toLowerCase() ==
                                  _tagFilter?.toLowerCase(),
                              onTap: () => setState(() {
                                final selected = stat.tag.toLowerCase() ==
                                    _tagFilter?.toLowerCase();
                                _tagFilter = selected ? null : stat.tag;
                              }),
                            ),
                          if (_tagFilter != null)
                            ActionChip(
                              key: const ValueKey('clear-tag-filter-chip'),
                              avatar: const Icon(Icons.close, size: 16),
                              label: const Text('清除标签'),
                              onPressed: () =>
                                  setState(() => _tagFilter = null),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? Center(
                      child: Text(
                        '还没有题目，先添加一个链接或手动录入。',
                        style: TextStyle(color: textSecondaryColor),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 680 ? 2 : 1;
                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            mainAxisExtent: 158,
                          ),
                          itemCount: visible.length,
                          itemBuilder: (context, index) => _ProblemListItem(
                            problem: visible[index],
                            onView: () => _openDetails(
                              context,
                              visible[index],
                            ),
                            onEdit: () =>
                                _openEditor(context, problem: visible[index]),
                            onStatusChanged: (status) => _changeStatus(
                              context,
                              visible[index],
                              status,
                            ),
                            onDelete: () => _delete(context, visible[index]),
                            onOpenProblem: () =>
                                _openProblem(context, visible[index]),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context, {
    ProblemRecord? problem,
  }) async {
    final saved = await showDialog<ProblemRecord>(
      context: context,
      builder: (_) => ProblemEditorDialog(
        initial: problem,
        onParseLink: widget.onParseLink,
      ),
    );
    if (saved == null) {
      return;
    }
    try {
      await widget.onSave(saved);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(problem == null ? '题目已添加' : '题目已保存')),
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

  Future<void> _changeStatus(
    BuildContext context,
    ProblemRecord problem,
    ProblemStatus status,
  ) async {
    if (problem.status == status) {
      return;
    }
    final updated = problem.copyWith(status: status);
    await widget.onSave(updated);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${problem.title} 已改为${problemStatusLabel(status)}'),
        ),
      );
  }

  Future<void> _delete(BuildContext context, ProblemRecord problem) async {
    await widget.onDelete(problem.id);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${problem.title} 已删除')),
    );
  }

  Future<void> _openProblem(BuildContext context, ProblemRecord problem) async {
    try {
      await widget.onOpenProblem(problem);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开题目失败：${normalizeError(error)}')),
      );
    }
  }

  Future<void> _openDetails(
    BuildContext context,
    ProblemRecord problem,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ProblemDetailsDialog(
        problem: problem,
        onEdit: () {
          Navigator.pop(context);
          _openEditor(context, problem: problem);
        },
        onOpenProblem: () {
          Navigator.pop(context);
          _openProblem(context, problem);
        },
        onStatusChanged: (status) {
          Navigator.pop(context);
          _changeStatus(context, problem, status);
        },
      ),
    );
  }
}

class _ProblemsHeader extends StatelessWidget {
  const _ProblemsHeader({
    required this.showBackButton,
    required this.onBack,
    required this.onAdd,
    required this.total,
    required this.pending,
    required this.accepted,
    required this.review,
  });

  final bool showBackButton;
  final VoidCallback onBack;
  final VoidCallback onAdd;
  final int total;
  final int pending;
  final int accepted;
  final int review;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (showBackButton) ...[
                IconButton(
                  key: const ValueKey('problems-back-button'),
                  tooltip: '返回',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 4),
              ],
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                ),
                child: Icon(Icons.auto_stories_outlined, color: accentColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '补题 / 错题本',
                      style: TextStyle(
                        color: textPrimaryColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pending == 0 ? '今天没有欠账，很清爽。' : '还剩 $pending 题待处理',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textSecondaryColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                key: const ValueKey('add-problem-button'),
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('添加'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _SummaryMetric(
                label: '全部',
                value: total,
                color: textPrimaryColor,
              ),
              const SizedBox(width: 8),
              _SummaryMetric(
                label: '待处理',
                value: pending,
                color: dangerColor,
              ),
              const SizedBox(width: 8),
              _SummaryMetric(
                label: '复盘中',
                value: review,
                color: _problemStatusColor(ProblemStatus.REVIEW),
              ),
              const SizedBox(width: 8),
              _SummaryMetric(
                label: '已通过',
                value: accepted,
                color: accentColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.16)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textSecondaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$value',
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProblemListItem extends StatelessWidget {
  const _ProblemListItem({
    required this.problem,
    required this.onView,
    required this.onEdit,
    required this.onStatusChanged,
    required this.onDelete,
    required this.onOpenProblem,
  });

  final ProblemRecord problem;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final ValueChanged<ProblemStatus> onStatusChanged;
  final VoidCallback onDelete;
  final VoidCallback onOpenProblem;

  @override
  Widget build(BuildContext context) {
    final statusColor = _problemStatusColor(problem.status);
    final preview = problem.analysis.isNotEmpty
        ? '题解：${problem.analysis}'
        : problem.note.isNotEmpty
            ? '备注：${problem.note}'
            : '';
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            color: statusColor.withValues(alpha: 0.85),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          problem.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textPrimaryColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ProblemStatusMenu(
                        problemId: problem.id,
                        status: problem.status,
                        onChanged: onStatusChanged,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.public, size: 14, color: textSecondaryColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${problemPlatformLabel(problem.platform)} · ${problem.date}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textSecondaryColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 22,
                    child: preview.isEmpty
                        ? Text(
                            problem.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textSecondaryColor,
                              fontSize: 12,
                            ),
                          )
                        : Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textPrimaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  const Spacer(),
                  if (problem.tags.isNotEmpty)
                    _ProblemTagStrip(tags: problem.tags),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _CompactActionButton(
                        key: ValueKey('view-problem-${problem.id}'),
                        tooltip: '查看详情',
                        onPressed: onView,
                        icon: Icons.article_outlined,
                      ),
                      _CompactActionButton(
                        key: ValueKey('open-problem-${problem.id}'),
                        tooltip: '前往题目',
                        onPressed: onOpenProblem,
                        icon: Icons.open_in_new,
                      ),
                      _CompactActionButton(
                        key: ValueKey('edit-problem-${problem.id}'),
                        tooltip: '编辑',
                        onPressed: onEdit,
                        icon: Icons.edit_outlined,
                      ),
                      _CompactActionButton(
                        key: ValueKey('mark-ac-problem-${problem.id}'),
                        tooltip: '勾选为已通过',
                        onPressed: problem.status == ProblemStatus.AC
                            ? null
                            : () => onStatusChanged(ProblemStatus.AC),
                        icon: Icons.check_circle_outline,
                      ),
                      _CompactActionButton(
                        key: ValueKey('delete-problem-${problem.id}'),
                        tooltip: '删除',
                        onPressed: onDelete,
                        icon: Icons.delete_outline,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactActionButton extends StatelessWidget {
  const _CompactActionButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _ProblemTagStrip extends StatelessWidget {
  const _ProblemTagStrip({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 5),
        itemBuilder: (context, index) => Pill(label: tags[index]),
      ),
    );
  }
}

class _ProblemDetailsDialog extends StatelessWidget {
  const _ProblemDetailsDialog({
    required this.problem,
    required this.onEdit,
    required this.onOpenProblem,
    required this.onStatusChanged,
  });

  final ProblemRecord problem;
  final VoidCallback onEdit;
  final VoidCallback onOpenProblem;
  final ValueChanged<ProblemStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(22, 18, 14, 0),
      contentPadding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
      actionsPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      title: Row(
        children: [
          Expanded(
            child: Text(
              problem.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          _ProblemStatusMenu(
            problemId: '${problem.id}-details',
            status: problem.status,
            onChanged: onStatusChanged,
          ),
        ],
      ),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  Pill(label: problemPlatformLabel(problem.platform)),
                  Pill(label: problem.date),
                  for (final tag in problem.tags) Pill(label: tag),
                ],
              ),
              const SizedBox(height: 12),
              _DetailLine(label: '链接', value: problem.url),
              const SizedBox(height: 12),
              _DetailSection(
                title: '备注',
                value: problem.note,
                emptyText: '暂无备注',
              ),
              const SizedBox(height: 12),
              _DetailSection(
                title: '题解分析',
                value: problem.analysis,
                emptyText: '暂无题解分析',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: onOpenProblem,
          icon: const Icon(Icons.open_in_new),
          label: const Text('前往题目'),
        ),
        TextButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('编辑'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: textSecondaryColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(
          value,
          style: TextStyle(color: textPrimaryColor, fontSize: 13),
        ),
      ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.value,
    required this.emptyText,
  });

  final String title;
  final String value;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final text = value.isEmpty ? emptyText : value;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardMutedColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: textPrimaryColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            text,
            style: TextStyle(
              color: value.isEmpty ? textSecondaryColor : textPrimaryColor,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagStatChip extends StatelessWidget {
  const _TagStatChip({
    required this.stat,
    required this.selected,
    required this.onTap,
  });

  final ProblemTagStat stat;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      key: ValueKey('problem-tag-filter-${stat.tag}'),
      selected: selected,
      label: Text('${stat.tag} ${stat.total}'),
      tooltip: '未通过 ${stat.pending} / 总数 ${stat.total}',
      onSelected: (_) => onTap(),
    );
  }
}

class _ProblemStatusMenu extends StatelessWidget {
  const _ProblemStatusMenu({
    required this.problemId,
    required this.status,
    required this.onChanged,
  });

  final String problemId;
  final ProblemStatus status;
  final ValueChanged<ProblemStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = _problemStatusColor(status);
    return PopupMenuButton<ProblemStatus>(
      key: ValueKey('problem-status-menu-$problemId'),
      tooltip: '切换状态',
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final item in ProblemStatus.values)
          PopupMenuItem(
            key: ValueKey('problem-status-option-$problemId-${item.name}'),
            value: item,
            child: Row(
              children: [
                Icon(
                  item == status
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: item == status
                      ? _problemStatusColor(item)
                      : textSecondaryColor,
                ),
                const SizedBox(width: 8),
                Text(problemStatusLabel(item)),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              status == ProblemStatus.AC
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              problemStatusLabel(status),
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _problemStatusColor(ProblemStatus status) {
  return switch (status) {
    ProblemStatus.AC => accentColor,
    ProblemStatus.REVIEW => const Color(0xFF8A6F19),
    ProblemStatus.TODO => textSecondaryColor,
    ProblemStatus.WA || ProblemStatus.TLE || ProblemStatus.RE => dangerColor,
  };
}
