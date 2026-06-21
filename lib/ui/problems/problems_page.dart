part of '../../main.dart';

class ProblemsPage extends StatefulWidget {
  const ProblemsPage({
    super.key,
    required this.problems,
    required this.onBack,
    required this.onParseLink,
    required this.onSave,
    required this.onDelete,
    required this.onMarkAccepted,
    required this.onOpenProblem,
  });

  final List<ProblemRecord> problems;
  final VoidCallback onBack;
  final Future<ParsedProblemLink> Function(String url) onParseLink;
  final Future<void> Function(ProblemRecord problem) onSave;
  final Future<void> Function(String id) onDelete;
  final Future<void> Function(ProblemRecord problem) onMarkAccepted;
  final Future<void> Function(ProblemRecord problem) onOpenProblem;

  @override
  State<ProblemsPage> createState() => _ProblemsPageState();
}

class _ProblemsPageState extends State<ProblemsPage> {
  final TextEditingController _queryController = TextEditingController();
  ProblemStatus? _statusFilter;
  ProblemPlatform? _platformFilter;
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
    );
    final pending = widget.problems
        .where((problem) => problem.status != ProblemStatus.AC)
        .length;
    return Scaffold(
      backgroundColor: _appSurfaceColor,
      body: Container(
        key: const ValueKey('problems-page'),
        color: _appSurfaceColor,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    key: const ValueKey('problems-back-button'),
                    tooltip: '返回',
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      '补题 / 错题本',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                  ),
                  _Pill(label: '待处理 $pending'),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    key: const ValueKey('add-problem-button'),
                    onPressed: () => _openEditor(context),
                    icon: const Icon(Icons.add),
                    label: const Text('添加'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                children: [
                  TextField(
                    key: const ValueKey('problem-search-field'),
                    controller: _queryController,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: '搜索标题、链接、标签或笔记',
                      isDense: true,
                      border: OutlineInputBorder(),
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
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<ProblemStatus?>(
                              value: null,
                              child: Text('全部状态'),
                            ),
                            for (final status in ProblemStatus.values)
                              DropdownMenuItem<ProblemStatus?>(
                                value: status,
                                child: Text(status.name),
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
                            isDense: true,
                            border: OutlineInputBorder(),
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
                          onChanged: (value) =>
                              setState(() => _platformFilter = value),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? const Center(
                      child: Text(
                        '还没有题目，先添加一个链接或手动录入。',
                        style: TextStyle(color: _textSecondaryColor),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) => _ProblemListItem(
                        problem: visible[index],
                        onEdit: () =>
                            _openEditor(context, problem: visible[index]),
                        onMarkAccepted:
                            visible[index].status == ProblemStatus.AC
                                ? null
                                : () => _markAccepted(context, visible[index]),
                        onDelete: () => _delete(context, visible[index]),
                        onOpenProblem: () =>
                            _openProblem(context, visible[index]),
                      ),
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

  Future<void> _markAccepted(
      BuildContext context, ProblemRecord problem) async {
    await widget.onMarkAccepted(problem);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${problem.title} 已标记 AC')),
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
}

class _ProblemListItem extends StatelessWidget {
  const _ProblemListItem({
    required this.problem,
    required this.onEdit,
    required this.onMarkAccepted,
    required this.onDelete,
    required this.onOpenProblem,
  });

  final ProblemRecord problem;
  final VoidCallback onEdit;
  final VoidCallback? onMarkAccepted;
  final VoidCallback onDelete;
  final VoidCallback onOpenProblem;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  problem.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _textPrimaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _ProblemStatusChip(status: problem.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${problemPlatformLabel(problem.platform)} · ${problem.date}',
            style: const TextStyle(color: _textSecondaryColor, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            problem.url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _textSecondaryColor, fontSize: 12),
          ),
          if (problem.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in problem.tags) _Pill(label: tag),
              ],
            ),
          ],
          if (problem.note.isNotEmpty || problem.analysis.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              problem.analysis.isNotEmpty ? problem.analysis : problem.note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _textPrimaryColor),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                key: ValueKey('open-problem-${problem.id}'),
                tooltip: '前往题目',
                onPressed: onOpenProblem,
                icon: const Icon(Icons.open_in_new),
              ),
              IconButton(
                key: ValueKey('edit-problem-${problem.id}'),
                tooltip: '编辑',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                key: ValueKey('mark-ac-problem-${problem.id}'),
                tooltip: '标记 AC',
                onPressed: onMarkAccepted,
                icon: const Icon(Icons.check_circle_outline),
              ),
              IconButton(
                key: ValueKey('delete-problem-${problem.id}'),
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

class _ProblemStatusChip extends StatelessWidget {
  const _ProblemStatusChip({required this.status});

  final ProblemStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status == ProblemStatus.AC ? _accentColor : _dangerColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.name,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}
