import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/solved_totals.dart';
import '../../models/problem_record.dart';
import '../../models/problem_batch.dart';
import '../../services/problem_book_service.dart';
import '../app_theme.dart';
import '../shared/app_surface_card.dart';
import '../shared/app_page_header.dart';
import '../shared/pill.dart';
import 'problem_editor.dart';

class ProblemsPage extends StatefulWidget {
  const ProblemsPage({
    super.key,
    required this.problems,
    this.folders = const [],
    this.onCreateFolder,
    this.onBatch,
    required this.onBack,
    required this.onParseLink,
    required this.onSave,
    required this.onDelete,
    required this.onOpenProblem,
    this.onToggleFavorite,
    this.onTogglePinned,
    this.onRestore,
    this.onPermanentDelete,
    this.onStartTraining,
    this.showBackButton = true,
    this.searchFocusNode,
  });

  final List<ProblemRecord> problems;
  final List<String> folders;
  final Future<void> Function(String)? onCreateFolder;
  final Future<void> Function(Set<String>, ProblemBatchChange)? onBatch;
  final VoidCallback onBack;
  final Future<ParsedProblemLink> Function(String url) onParseLink;
  final Future<void> Function(ProblemRecord problem) onSave;
  final Future<void> Function(String id) onDelete;
  final Future<void> Function(ProblemRecord problem) onOpenProblem;
  final Future<void> Function(String id)? onRestore;
  final Future<void> Function(String id)? onPermanentDelete;
  final Future<void> Function(ProblemRecord problem)? onStartTraining;
  final Future<void> Function(String id)? onToggleFavorite;
  final Future<void> Function(String id)? onTogglePinned;
  final bool showBackButton;
  final FocusNode? searchFocusNode;

  @override
  State<ProblemsPage> createState() => _ProblemsPageState();
}

class _ProblemsPageState extends State<ProblemsPage> {
  final TextEditingController _queryController = TextEditingController();
  ProblemWorkflowStatus? _statusFilter;
  ProblemPlatform? _platformFilter;
  final Set<String> _tagFilters = {};
  bool _matchAllTags = false;
  bool _batchBusy = false;
  List<String> get _folders =>
      parseProblemFolders(widget.folders, widget.problems);
  String? _folderFilter;
  String _query = '';
  String _specialFilter = '全部';
  bool _filtersExpanded = false;
  final Set<String> _selectedIds = <String>{};

  @override
  void didUpdateWidget(covariant ProblemsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final availableIds = widget.problems.map((problem) => problem.id).toSet();
    _selectedIds.removeWhere((id) => !availableIds.contains(id));
    final folders = _folders;
    if (_folderFilter != null &&
        _folderFilter != '' &&
        !folders.contains(_folderFilter)) {
      _folderFilter = null;
    }
  }

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
      workflowStatus: _statusFilter,
      platform: _platformFilter,
      tags: _tagFilters,
      matchAllTags: _matchAllTags,
      folder: _folderFilter,
    ).where((problem) {
      return switch (_specialFilter) {
        '收藏' => problem.isFavorite,
        '置顶' => problem.isPinned,
        '最近打开' => problem.lastOpenedAt != null,
        '最近编辑' => true,
        _ => true,
      };
    }).toList()
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        if (_specialFilter == '最近打开') {
          return (b.lastOpenedAt ?? DateTime(0))
              .compareTo(a.lastOpenedAt ?? DateTime(0));
        }
        return b.updatedAt.compareTo(a.updatedAt);
      });
    final tagStats = buildProblemTagStats(
      widget.problems,
      platform: _platformFilter,
    );
    final pending = widget.problems
        .where((problem) =>
            problem.workflowStatus == ProblemWorkflowStatus.backlog ||
            problem.workflowStatus == ProblemWorkflowStatus.active ||
            problem.workflowStatus == ProblemWorkflowStatus.review)
        .length;
    final accepted = widget.problems
        .where((problem) =>
            problem.workflowStatus == ProblemWorkflowStatus.mastered)
        .length;
    final review = widget.problems
        .where(
            (problem) => problem.workflowStatus == ProblemWorkflowStatus.review)
        .length;
    final activeFilterCount = [
      _query.trim().isNotEmpty,
      _specialFilter != '全部',
      _folderFilter != null,
      _statusFilter != null,
      _platformFilter != null,
      _tagFilters.isNotEmpty,
    ].where((active) => active).length;
    return Scaffold(
      backgroundColor: appSurfaceColor,
      body: LayoutBuilder(builder: (context, constraints) {
        final showSidebar = constraints.maxWidth >= 840;
        return Column(key: const ValueKey('problems-page'), children: [
          _ProblemsHeader(
              showBackButton: widget.showBackButton,
              onBack: widget.onBack,
              onAdd: () => _openEditor(context),
              total: widget.problems.length,
              pending: pending,
              accepted: accepted,
              review: review),
          Expanded(
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                if (showSidebar)
                  SizedBox(
                      width: 174, child: _folderNavigation(vertical: true)),
                Expanded(
                    child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!showSidebar)
                                _folderNavigation(vertical: false),
                              ConstrainedBox(
                                  constraints: BoxConstraints(
                                      maxHeight: constraints.maxHeight * 0.42),
                                  child: SingleChildScrollView(
                                    child: _filterControls(
                                        context, tagStats, activeFilterCount),
                                  )),
                              if (_selectedIds.isNotEmpty)
                                AbsorbPointer(
                                    absorbing: _batchBusy,
                                    child: _BatchToolbar(
                                      selectedCount: _selectedIds.length,
                                      allVisibleSelected: visible.isNotEmpty &&
                                          visible.every((p) =>
                                              _selectedIds.contains(p.id)),
                                      onToggleAll: () => setState(() {
                                        final all = visible.isNotEmpty &&
                                            visible.every((p) =>
                                                _selectedIds.contains(p.id));
                                        if (all) {
                                          _selectedIds.removeAll(
                                              visible.map((p) => p.id));
                                        } else {
                                          _selectedIds
                                              .addAll(visible.map((p) => p.id));
                                        }
                                      }),
                                      onClear: () =>
                                          setState(() => _selectedIds.clear()),
                                      onArchive: () =>
                                          _archiveSelected(context),
                                      onTags: () => _editSelectedTags(context),
                                      onRemoveTags: () => _editSelectedTags(
                                          context,
                                          remove: true),
                                      onMove: () => _moveSelected(context),
                                      onExport: () => _exportSelected(context),
                                      onChangeStatus: (status) =>
                                          _changeSelectedStatus(
                                              context, status),
                                    )),
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(children: [
                                    Checkbox(
                                        key: const ValueKey(
                                            'select-all-problems'),
                                        value: visible.isNotEmpty &&
                                            visible.every((p) =>
                                                _selectedIds.contains(p.id)),
                                        onChanged: visible.isEmpty
                                            ? null
                                            : (checked) => setState(() {
                                                  if (checked == true) {
                                                    _selectedIds.addAll(visible
                                                        .map((p) => p.id));
                                                  } else {
                                                    _selectedIds.removeAll(
                                                        visible
                                                            .map((p) => p.id));
                                                  }
                                                })),
                                    Text('全选当前结果',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                    const Spacer(),
                                    Text('${visible.length} 道题目',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                  ])),
                              Expanded(
                                  child: visible.isEmpty
                                      ? ListView(children: [
                                          AppEmptyState(
                                              icon: Icons.auto_stories_outlined,
                                              title: widget.problems.isEmpty
                                                  ? '从第一道题开始'
                                                  : '没有匹配的题目',
                                              message: widget.problems.isEmpty
                                                  ? '收藏一道值得再做的题，把思路留在这里。'
                                                  : '试试其他文件夹或减少筛选条件。',
                                              action: TextButton.icon(
                                                  onPressed: () =>
                                                      _openEditor(context),
                                                  icon: const Icon(Icons.add,
                                                      size: 17),
                                                  label: const Text('添加')))
                                        ])
                                      : Container(
                                          decoration: BoxDecoration(
                                              color: cardColor,
                                              border: Border.all(
                                                  color: borderColor),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      appRadiusCard)),
                                          clipBehavior: Clip.antiAlias,
                                          child: ListView.separated(
                                            key: const ValueKey(
                                                'problem-results-list'),
                                            padding: EdgeInsets.zero,
                                            itemCount: visible.length,
                                            separatorBuilder: (_, __) =>
                                                Divider(
                                                    height: 1,
                                                    indent: 16,
                                                    endIndent: 16,
                                                    color: borderColor),
                                            itemBuilder: (context, index) =>
                                                _ProblemListItem(
                                              problem: visible[index],
                                              selected: _selectedIds
                                                  .contains(visible[index].id),
                                              onSelected: (value) =>
                                                  setState(() {
                                                if (value) {
                                                  _selectedIds
                                                      .add(visible[index].id);
                                                } else {
                                                  _selectedIds.remove(
                                                      visible[index].id);
                                                }
                                              }),
                                              onView: () => _openDetails(
                                                context,
                                                visible[index],
                                              ),
                                              onEdit: () => _openEditor(context,
                                                  problem: visible[index]),
                                              onStatusChanged: (status) =>
                                                  _changeStatus(
                                                context,
                                                visible[index],
                                                status,
                                              ),
                                              onDelete: () => _delete(
                                                  context, visible[index]),
                                              onOpenProblem: () => _openProblem(
                                                  context, visible[index]),
                                              onToggleFavorite: widget
                                                          .onToggleFavorite ==
                                                      null
                                                  ? null
                                                  : () =>
                                                      widget.onToggleFavorite!(
                                                          visible[index].id),
                                              onTogglePinned:
                                                  widget.onTogglePinned == null
                                                      ? null
                                                      : () => widget
                                                              .onTogglePinned!(
                                                          visible[index].id),
                                              onRestore: widget.onRestore ==
                                                      null
                                                  ? null
                                                  : () => _restore(
                                                      context, visible[index]),
                                              onStartTraining:
                                                  widget.onStartTraining == null
                                                      ? null
                                                      : () => _startTraining(
                                                            context,
                                                            visible[index],
                                                          ),
                                            ),
                                          ))),
                            ]))),
              ])),
        ]);
      }),
    );
  }

  Widget _filterControls(BuildContext context, List<ProblemTagStat> tagStats,
          int activeFilterCount) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('problem-search-field'),
                    controller: _queryController,
                    focusNode: widget.searchFocusNode,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: '搜索标题、链接、标签或笔记 (Ctrl+F)',
                      isDense: true,
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: '清除搜索',
                              onPressed: () {
                                _queryController.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.clear),
                            ),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.outlined(
                  key: const ValueKey('problem-filters-toggle'),
                  tooltip: _filtersExpanded ? '收起筛选' : '展开筛选',
                  onPressed: () =>
                      setState(() => _filtersExpanded = !_filtersExpanded),
                  icon: Badge(
                    isLabelVisible: activeFilterCount > 0,
                    label: Text('$activeFilterCount'),
                    child: Icon(
                      _filtersExpanded
                          ? Icons.filter_list_off
                          : Icons.filter_list,
                    ),
                  ),
                ),
              ],
            ),
            if (activeFilterCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '已应用 $activeFilterCount 个筛选条件',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _filtersExpanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  key: const ValueKey('problem-special-filter'),
                                  initialValue: _specialFilter,
                                  decoration:
                                      const InputDecoration(labelText: '快速访问'),
                                  items: const [
                                    DropdownMenuItem(
                                        value: '全部', child: Text('全部题目')),
                                    DropdownMenuItem(
                                        value: '收藏', child: Text('收藏')),
                                    DropdownMenuItem(
                                        value: '置顶', child: Text('置顶')),
                                    DropdownMenuItem(
                                        value: '最近打开', child: Text('最近打开')),
                                    DropdownMenuItem(
                                        value: '最近编辑', child: Text('最近编辑')),
                                  ],
                                  onChanged: (value) => setState(
                                      () => _specialFilter = value ?? '全部'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<
                                    ProblemWorkflowStatus?>(
                                  isExpanded: true,
                                  key: const ValueKey('problem-status-filter'),
                                  initialValue: _statusFilter,
                                  decoration:
                                      const InputDecoration(labelText: '状态'),
                                  items: [
                                    const DropdownMenuItem<
                                        ProblemWorkflowStatus?>(
                                      value: null,
                                      child: Text('全部状态'),
                                    ),
                                    for (final status
                                        in ProblemWorkflowStatus.values)
                                      DropdownMenuItem<ProblemWorkflowStatus?>(
                                        value: status,
                                        child: Text(
                                            problemWorkflowStatusLabel(status)),
                                      ),
                                  ],
                                  onChanged: (value) =>
                                      setState(() => _statusFilter = value),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child:
                                    DropdownButtonFormField<ProblemPlatform?>(
                                  isExpanded: true,
                                  key:
                                      const ValueKey('problem-platform-filter'),
                                  initialValue: _platformFilter,
                                  decoration:
                                      const InputDecoration(labelText: '平台'),
                                  items: [
                                    const DropdownMenuItem<ProblemPlatform?>(
                                      value: null,
                                      child: Text('全部平台'),
                                    ),
                                    for (final platform
                                        in ProblemPlatform.values)
                                      DropdownMenuItem<ProblemPlatform?>(
                                        value: platform,
                                        child: Text(
                                            problemPlatformLabel(platform)),
                                      ),
                                  ],
                                  onChanged: (value) => setState(() {
                                    _platformFilter = value;
                                    _tagFilters.clear();
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            if (tagStats.isNotEmpty) ...[
              const SizedBox(height: 6),
              SizedBox(
                height: 38,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final stat in tagStats) ...[
                        _TagStatChip(
                          stat: stat,
                          selected:
                              _tagFilters.contains(stat.tag.toLowerCase()),
                          onTap: () => setState(() {
                            final key = stat.tag.toLowerCase();
                            if (!_tagFilters.add(key)) {
                              _tagFilters.remove(key);
                            }
                          }),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (_tagFilters.isNotEmpty) ...[
                        FilterChip(
                            key: const ValueKey('problem-tag-match-all'),
                            label: const Text('匹配全部标签'),
                            selected: _matchAllTags,
                            onSelected: (value) =>
                                setState(() => _matchAllTags = value)),
                        const SizedBox(width: 6),
                        ActionChip(
                          key: const ValueKey('clear-tag-filter-chip'),
                          avatar: const Icon(Icons.close, size: 16),
                          label: const Text('清除标签'),
                          onPressed: () => setState(() => _tagFilters.clear()),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );

  Widget _folderNavigation({required bool vertical}) {
    Widget folder(String label, String? value, IconData icon) {
      final count = widget.problems
          .where((p) =>
              p.workflowStatus != ProblemWorkflowStatus.archived &&
              (value == null || p.folder.toLowerCase() == value.toLowerCase()))
          .length;
      final selected = _folderFilter == value;
      return Padding(
          padding: const EdgeInsets.only(bottom: 4, right: 4),
          child: TextButton(
              key: ValueKey('problem-folder-nav-${value ?? 'all'}'),
              style: TextButton.styleFrom(
                  backgroundColor:
                      selected ? cardMutedColor : Colors.transparent,
                  foregroundColor: selected ? accentColor : textSecondaryColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
              onPressed: () => setState(() => _folderFilter = value),
              child: Row(
                  mainAxisSize: vertical ? MainAxisSize.max : MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16),
                    const SizedBox(width: 8),
                    if (vertical)
                      Expanded(
                          child: Text(label,
                              maxLines: 1, overflow: TextOverflow.ellipsis))
                    else
                      Text(label),
                    const SizedBox(width: 10),
                    Text('$count',
                        style: Theme.of(context).textTheme.bodySmall),
                  ])));
    }

    final items = [
      folder('全部题目', null, Icons.library_books_outlined),
      folder('未分类', '', Icons.inbox_outlined),
      for (final name in _folders) folder(name, name, Icons.folder_outlined),
    ];
    final create = widget.onCreateFolder == null
        ? const SizedBox.shrink()
        : TextButton.icon(
            key: const ValueKey('create-problem-folder'),
            onPressed: () => _createFolder(context),
            icon: const Icon(Icons.create_new_folder_outlined, size: 17),
            label: const Text('新建文件夹'));
    if (!vertical) {
      return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
              height: 42,
              child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [...items, create])));
    }
    return Container(
        decoration: BoxDecoration(
            border: Border(right: BorderSide(color: borderColor))),
        child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 16),
            children: [
              Padding(
                  padding: const EdgeInsets.only(left: 10, bottom: 16),
                  child: Text('文件夹',
                      style: Theme.of(context).textTheme.bodySmall)),
              ...items,
              const SizedBox(height: 12),
              create,
            ]));
  }

  Future<String?> _askFolder(BuildContext context, {required bool move}) async {
    return showDialog<String>(
        context: context,
        builder: (_) => _ProblemTextDialog(
            title: move ? '移动到文件夹' : '新建文件夹',
            label: '文件夹名称',
            helper: move ? '留空表示移回未分类' : '空文件夹也会保存',
            confirmLabel: move ? '移动' : '创建',
            allowEmpty: move,
            suggestions: _folders,
            inputKey: const ValueKey('folder-name-input')));
  }

  Future<void> _createFolder(BuildContext context) async {
    final name = await _askFolder(context, move: false);
    if (name == null || !context.mounted) return;
    try {
      await widget.onCreateFolder!(name);
      if (mounted) {
        setState(() {
          _folderFilter = name;
          _filtersExpanded = true;
        });
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('创建文件夹失败：$error')));
      }
    }
  }

  Future<void> _moveSelected(BuildContext context) async {
    final name = await _askFolder(context, move: true);
    if (name == null || !context.mounted) return;
    if (!await _applyBatch(ProblemBatchChange(folder: name))) return;
    if (mounted) setState(() => _selectedIds.clear());
  }

  Future<bool> _applyBatch(ProblemBatchChange change) async {
    if (_batchBusy) return false;
    setState(() => _batchBusy = true);
    try {
      if (widget.onBatch != null) {
        await widget.onBatch!(Set.of(_selectedIds), change);
      } else {
        final now = DateTime.now();
        for (final problem
            in widget.problems.where((p) => _selectedIds.contains(p.id))) {
          await widget.onSave(change.apply(problem, now));
        }
      }
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('批量操作失败：$error')));
      }
      return false;
    } finally {
      if (mounted) setState(() => _batchBusy = false);
    }
  }

  Future<void> _editSelectedTags(BuildContext context,
      {bool remove = false}) async {
    final tagsText = await showDialog<String>(
        context: context,
        builder: (_) => _ProblemTextDialog(
            title: remove ? '批量移除标签' : '批量添加标签',
            label: '标签，逗号分隔',
            helper: '例如：图论, 待重做',
            confirmLabel: remove ? '移除标签' : '添加标签'));
    if (tagsText == null) return;
    final tags = normalizeProblemTags(tagsText.split(RegExp('[,，]')));
    if (tags.isEmpty) return;
    final selected =
        widget.problems.where((p) => _selectedIds.contains(p.id)).toList();
    if (!await _applyBatch(ProblemBatchChange(
        addTags: remove ? const [] : tags,
        removeTags: remove ? tags : const []))) {
      return;
    }
    if (!context.mounted) return;
    setState(() => _selectedIds.clear());
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('已更新 ${selected.length} 项标签')));
  }

  Future<void> _exportSelected(BuildContext context) async {
    final selected =
        widget.problems.where((p) => _selectedIds.contains(p.id)).toList();
    final path = await FilePicker.platform.saveFile(
        dialogTitle: '导出题目 Markdown',
        fileName: 'oj-problems.md',
        type: FileType.custom,
        allowedExtensions: ['md']);
    if (path == null) return;
    final buffer = StringBuffer('# OJ 题目导出\n\n');
    for (final p in selected) {
      buffer.writeln(
          '## [${p.title}](${p.url})\n\n- 平台：${problemPlatformLabel(p.platform)}\n- 状态：${problemWorkflowStatusLabel(p.workflowStatus)}\n- 标签：${p.tags.join('、')}\n- 日期：${p.date}\n\n${p.note.isEmpty ? '' : '### 备注\n${p.note}\n\n'}${p.analysis.isEmpty ? '' : '### 题解\n${p.analysis}\n\n'}---\n');
    }
    await File(path).writeAsString(buffer.toString());
    if (!context.mounted) return;
    setState(() => _selectedIds.clear());
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('已导出 ${selected.length} 项')));
  }

  Future<void> _changeSelectedStatus(
      BuildContext context, ProblemWorkflowStatus status) async {
    final selected =
        widget.problems.where((p) => _selectedIds.contains(p.id)).toList();
    if (!await _applyBatch(ProblemBatchChange(status: status))) return;
    if (!context.mounted) return;
    setState(() => _selectedIds.clear());
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('已批量修改 ${selected.length} 项')));
  }

  Future<void> _archiveSelected(BuildContext context) async {
    final selected =
        widget.problems.where((p) => _selectedIds.contains(p.id)).toList();
    final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
                    title: const Text('批量归档？'),
                    content: Text('将归档 ${selected.length} 道题目，之后仍可恢复。'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('取消')),
                      FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('归档'))
                    ])) ??
        false;
    if (!confirmed) return;
    if (!await _applyBatch(
        const ProblemBatchChange(status: ProblemWorkflowStatus.archived))) {
      return;
    }
    if (!context.mounted) return;
    setState(() => _selectedIds.clear());
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('已归档 ${selected.length} 项')));
  }

  Future<void> _openEditor(
    BuildContext context, {
    ProblemRecord? problem,
  }) async {
    final saved = await showDialog<ProblemRecord>(
      context: context,
      builder: (_) => ProblemEditorDialog(
        initial: problem,
        folders: _folders,
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
    ProblemWorkflowStatus status,
  ) async {
    if (problem.workflowStatus == status) {
      return;
    }
    final updated = problem.copyWith(
      workflowStatus: status,
      archivedAt:
          status == ProblemWorkflowStatus.archived ? DateTime.now() : null,
      clearArchivedAt: status != ProblemWorkflowStatus.archived,
    );
    await widget.onSave(updated);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content:
              Text('${problem.title} 已改为${problemWorkflowStatusLabel(status)}'),
        ),
      );
  }

  Future<void> _delete(BuildContext context, ProblemRecord problem) async {
    await widget.onDelete(problem.id);
    if (!context.mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${problem.title} 已归档'),
          action: widget.onRestore == null
              ? null
              : SnackBarAction(
                  label: '撤销',
                  onPressed: () => widget.onRestore!(problem.id),
                ),
        ),
      );
  }

  Future<void> _restore(BuildContext context, ProblemRecord problem) async {
    await widget.onRestore?.call(problem.id);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${problem.title} 已恢复到待安排')),
    );
  }

  Future<void> _startTraining(
    BuildContext context,
    ProblemRecord problem,
  ) async {
    try {
      await widget.onStartTraining?.call(problem);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('开始训练失败：${normalizeError(error)}')),
      );
    }
  }

  Future<void> _permanentlyDelete(
    BuildContext context,
    ProblemRecord problem,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('永久删除题目？'),
            content: Text('将同时清理「${problem.title}」的队列和题单引用，此操作无法撤销。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('永久删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    await widget.onPermanentDelete?.call(problem.id);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${problem.title} 已永久删除')),
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
        onStartTraining: widget.onStartTraining == null
            ? null
            : () {
                Navigator.pop(context);
                _startTraining(context, problem);
              },
        onArchiveOrRestore:
            problem.workflowStatus == ProblemWorkflowStatus.archived
                ? (widget.onRestore == null
                    ? null
                    : () {
                        Navigator.pop(context);
                        _restore(context, problem);
                      })
                : () {
                    Navigator.pop(context);
                    _delete(context, problem);
                  },
        onPermanentDelete: widget.onPermanentDelete == null
            ? null
            : () {
                Navigator.pop(context);
                _permanentlyDelete(context, problem);
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AppPageHeader(
            title: '补题 / 错题本',
            subtitle: '收集值得再做的题，再回到训练中。',
            leading: showBackButton
                ? IconButton(
                    key: const ValueKey('problems-back-button'),
                    tooltip: '返回',
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back))
                : null,
            actions: [
              FilledButton.icon(
                  key: const ValueKey('add-problem-button'),
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加'))
            ],
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 20, runSpacing: 4, children: [
            Text('$total 全部', style: Theme.of(context).textTheme.bodySmall),
            Text('$pending 待处理', style: Theme.of(context).textTheme.bodySmall),
            Text('$review 待复习', style: Theme.of(context).textTheme.bodySmall),
            Text('$accepted 已掌握', style: Theme.of(context).textTheme.bodySmall),
          ]),
        ]),
      );
}

class _BatchToolbar extends StatelessWidget {
  const _BatchToolbar(
      {required this.selectedCount,
      required this.allVisibleSelected,
      required this.onToggleAll,
      required this.onClear,
      required this.onArchive,
      required this.onTags,
      required this.onRemoveTags,
      required this.onMove,
      required this.onExport,
      required this.onChangeStatus});
  final int selectedCount;
  final bool allVisibleSelected;
  final VoidCallback onToggleAll;
  final VoidCallback onClear;
  final VoidCallback onArchive;
  final VoidCallback onTags;
  final VoidCallback onRemoveTags;
  final VoidCallback onMove;
  final VoidCallback onExport;
  final ValueChanged<ProblemWorkflowStatus> onChangeStatus;
  @override
  Widget build(BuildContext context) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(appRadiusControl),
          border: Border.all(color: accentColor.withValues(alpha: 0.25))),
      child: Row(children: [
        Checkbox(value: allVisibleSelected, onChanged: (_) => onToggleAll()),
        Text('已选 $selectedCount 项'),
        const Spacer(),
        PopupMenuButton<ProblemWorkflowStatus>(
            tooltip: '批量修改状态',
            onSelected: onChangeStatus,
            itemBuilder: (_) => [
                  for (final status in ProblemWorkflowStatus.values)
                    PopupMenuItem(
                        value: status,
                        child: Text(problemWorkflowStatusLabel(status)))
                ],
            child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.edit_note_outlined))),
        IconButton(
            tooltip: '移动到文件夹',
            onPressed: onMove,
            icon: const Icon(Icons.drive_file_move_outlined)),
        IconButton(
            tooltip: '移除标签',
            onPressed: onRemoveTags,
            icon: const Icon(Icons.label_off_outlined)),
        IconButton(
            tooltip: '批量标签',
            onPressed: onTags,
            icon: const Icon(Icons.sell_outlined)),
        IconButton(
            tooltip: '导出 Markdown',
            onPressed: onExport,
            icon: const Icon(Icons.file_download_outlined)),
        IconButton(
            tooltip: '批量归档',
            onPressed: onArchive,
            icon: const Icon(Icons.archive_outlined)),
        IconButton(
            tooltip: '取消选择', onPressed: onClear, icon: const Icon(Icons.close))
      ]));
}

class _ProblemListItem extends StatelessWidget {
  const _ProblemListItem({
    required this.problem,
    required this.selected,
    required this.onSelected,
    required this.onView,
    required this.onEdit,
    required this.onStatusChanged,
    required this.onDelete,
    required this.onOpenProblem,
    this.onToggleFavorite,
    this.onTogglePinned,
    this.onRestore,
    this.onStartTraining,
  });

  final ProblemRecord problem;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final ValueChanged<ProblemWorkflowStatus> onStatusChanged;
  final VoidCallback onDelete;
  final VoidCallback onOpenProblem;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onTogglePinned;
  final VoidCallback? onRestore;
  final VoidCallback? onStartTraining;

  @override
  Widget build(BuildContext context) {
    final preview = problem.analysis.isNotEmpty
        ? '题解：${problem.analysis}'
        : problem.note.isNotEmpty
            ? '备注：${problem.note}'
            : '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 42,
            child: Checkbox(
                key: ValueKey('problem-select-${problem.id}'),
                value: selected,
                onChanged: (value) => onSelected(value ?? false)),
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
                        child: InkWell(
                            onTap: onView,
                            child: Text(
                              problem.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textPrimaryColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            )),
                      ),
                      const SizedBox(width: 8),
                      _ProblemStatusMenu(
                        problemId: problem.id,
                        status: problem.workflowStatus,
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
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  if (problem.tags.isNotEmpty || problem.folder.isNotEmpty)
                    _ProblemTagStrip(
                      tags: [
                        if (problem.folder.isNotEmpty) '文件夹：${problem.folder}',
                        ...problem.tags,
                      ],
                    ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      children: [
                        _CompactActionButton(
                          key: ValueKey('favorite-problem-${problem.id}'),
                          tooltip: problem.isFavorite ? '取消收藏' : '收藏',
                          onPressed: onToggleFavorite,
                          icon: problem.isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                        ),
                        _CompactActionButton(
                          key: ValueKey('pin-problem-${problem.id}'),
                          tooltip: problem.isPinned ? '取消置顶' : '置顶',
                          onPressed: onTogglePinned,
                          icon: problem.isPinned
                              ? Icons.push_pin
                              : Icons.push_pin_outlined,
                        ),
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
                          key: ValueKey('start-training-${problem.id}'),
                          tooltip: '开始训练',
                          onPressed: problem.workflowStatus ==
                                  ProblemWorkflowStatus.archived
                              ? null
                              : onStartTraining,
                          icon: Icons.play_arrow,
                        ),
                        _CompactActionButton(
                          key: ValueKey('edit-problem-${problem.id}'),
                          tooltip: '编辑',
                          onPressed: onEdit,
                          icon: Icons.edit_outlined,
                        ),
                        _CompactActionButton(
                          key: ValueKey('mark-ac-problem-${problem.id}'),
                          tooltip: '标记为已掌握',
                          onPressed: problem.workflowStatus ==
                                  ProblemWorkflowStatus.mastered
                              ? null
                              : () => onStatusChanged(
                                    ProblemWorkflowStatus.mastered,
                                  ),
                          icon: Icons.check_circle_outline,
                        ),
                        _CompactActionButton(
                          key: ValueKey('delete-problem-${problem.id}'),
                          tooltip: problem.workflowStatus ==
                                  ProblemWorkflowStatus.archived
                              ? '恢复'
                              : '归档',
                          onPressed: problem.workflowStatus ==
                                  ProblemWorkflowStatus.archived
                              ? onRestore
                              : onDelete,
                          icon: problem.workflowStatus ==
                                  ProblemWorkflowStatus.archived
                              ? Icons.unarchive_outlined
                              : Icons.archive_outlined,
                        ),
                      ],
                    ),
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
    this.onStartTraining,
    this.onArchiveOrRestore,
    this.onPermanentDelete,
  });

  final ProblemRecord problem;
  final VoidCallback onEdit;
  final VoidCallback onOpenProblem;
  final ValueChanged<ProblemWorkflowStatus> onStatusChanged;
  final VoidCallback? onStartTraining;
  final VoidCallback? onArchiveOrRestore;
  final VoidCallback? onPermanentDelete;

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
            status: problem.workflowStatus,
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
                  if (problem.folder.isNotEmpty)
                    Pill(label: '文件夹：${problem.folder}'),
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
        if (onPermanentDelete != null)
          IconButton(
            key: ValueKey('permanent-delete-problem-${problem.id}'),
            tooltip: '永久删除',
            onPressed: onPermanentDelete,
            icon: const Icon(Icons.delete_forever_outlined),
          ),
        if (onArchiveOrRestore != null)
          IconButton(
            tooltip: problem.workflowStatus == ProblemWorkflowStatus.archived
                ? '恢复'
                : '归档',
            onPressed: onArchiveOrRestore,
            icon: Icon(
              problem.workflowStatus == ProblemWorkflowStatus.archived
                  ? Icons.unarchive_outlined
                  : Icons.archive_outlined,
            ),
          ),
        if (onStartTraining != null &&
            problem.workflowStatus != ProblemWorkflowStatus.archived)
          TextButton.icon(
            onPressed: onStartTraining,
            icon: const Icon(Icons.play_arrow),
            label: const Text('开始训练'),
          ),
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
            fontWeight: FontWeight.w500,
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
              fontWeight: FontWeight.w600,
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
  final ProblemWorkflowStatus status;
  final ValueChanged<ProblemWorkflowStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = _problemStatusColor(status);
    return PopupMenuButton<ProblemWorkflowStatus>(
      key: ValueKey('problem-status-menu-$problemId'),
      tooltip: '切换状态',
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final item in ProblemWorkflowStatus.values)
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
                Text(problemWorkflowStatusLabel(item)),
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
              status == ProblemWorkflowStatus.mastered
                  ? Icons.check_circle
                  : status == ProblemWorkflowStatus.archived
                      ? Icons.archive_outlined
                      : Icons.radio_button_unchecked,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              problemWorkflowStatusLabel(status),
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _problemStatusColor(ProblemWorkflowStatus status) {
  return switch (status) {
    ProblemWorkflowStatus.mastered => accentColor,
    ProblemWorkflowStatus.review => const Color(0xFF8A6F19),
    ProblemWorkflowStatus.backlog => textSecondaryColor,
    ProblemWorkflowStatus.active => dangerColor,
    ProblemWorkflowStatus.archived => const Color(0xFF667085),
  };
}

class _ProblemTextDialog extends StatefulWidget {
  const _ProblemTextDialog(
      {required this.title,
      required this.label,
      required this.helper,
      required this.confirmLabel,
      this.allowEmpty = false,
      this.suggestions = const [],
      this.inputKey});
  final String title, label, helper, confirmLabel;
  final bool allowEmpty;
  final List<String> suggestions;
  final Key? inputKey;
  @override
  State<_ProblemTextDialog> createState() => _ProblemTextDialogState();
}

class _ProblemTextDialogState extends State<_ProblemTextDialog> {
  final _input = TextEditingController();
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _submit() {
    if (widget.allowEmpty || _input.text.trim().isNotEmpty) {
      Navigator.pop(context, _input.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text(widget.title),
          content: SizedBox(
              width: 360,
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                        key: widget.inputKey,
                        controller: _input,
                        autofocus: true,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                            labelText: widget.label,
                            helperText: widget.helper)),
                    if (widget.suggestions.isNotEmpty)
                      ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: SingleChildScrollView(
                              child: Wrap(spacing: 6, children: [
                            for (final folder in widget.suggestions)
                              ActionChip(
                                  label: Text(folder),
                                  onPressed: () => _input.text = folder)
                          ]))),
                  ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消')),
            FilledButton(onPressed: _submit, child: Text(widget.confirmLabel))
          ]);
}
