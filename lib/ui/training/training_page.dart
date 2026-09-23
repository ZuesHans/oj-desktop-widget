import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/time.dart';
import '../../models/contest_record.dart';
import '../../models/problem_record.dart';
import '../../models/training.dart';
import '../../services/training_service.dart';
import '../app_theme.dart';
import '../shared/app_surface_card.dart';
import '../shared/pill.dart';

class TrainingFinishInput {
  const TrainingFinishInput({
    required this.result,
    required this.assistance,
    required this.mistakes,
    required this.reflection,
    this.favoriteListId,
  });

  final AttemptResult result;
  final AssistanceLevel assistance;
  final List<MistakeCategory> mistakes;
  final String reflection;
  final String? favoriteListId;
}

class TrainingPage extends StatefulWidget {
  const TrainingPage({
    super.key,
    required this.problems,
    required this.training,
    required this.analytics,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    required this.onFinish,
    required this.onAddTasks,
    required this.onMoveTask,
    required this.onRemoveTask,
    required this.onSaveList,
    required this.onDeleteList,
    required this.onOpenProblem,
    this.contests = const [],
  });

  final List<ProblemRecord> problems;
  final List<ContestRecord> contests;
  final TrainingStoreData training;
  final TrainingAnalytics analytics;
  final Future<void> Function(ProblemRecord problem, String? taskId) onStart;
  final Future<void> Function() onPause;
  final Future<void> Function() onResume;
  final Future<void> Function() onCancel;
  final Future<void> Function(TrainingFinishInput input) onFinish;
  final Future<void> Function(Iterable<String> problemIds, String trainingDate)
      onAddTasks;
  final Future<void> Function(String taskId, String trainingDate) onMoveTask;
  final Future<void> Function(String taskId) onRemoveTask;
  final Future<void> Function(TrainingList list) onSaveList;
  final Future<void> Function(String id) onDeleteList;
  final Future<void> Function(ProblemRecord problem) onOpenProblem;

  @override
  State<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late DateTime _selectedDate;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _selectedDate = trainingDayStartFor(DateTime.now());
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant TrainingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  void _syncTicker() {
    final shouldTick = widget.training.activeAttempt != null &&
        !widget.training.activeAttempt!.isPaused;
    if (shouldTick && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!shouldTick && _ticker != null) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('training-page'),
      backgroundColor: appSurfaceColor,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(appRadiusControl),
                  ),
                  child: Icon(Icons.timer_outlined, color: accentColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '训练工作台',
                        style: TextStyle(
                          color: textPrimaryColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '自主安排训练，保留每一次尝试与复盘',
                        style: TextStyle(color: textSecondaryColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: '每日安排'),
              Tab(text: '题单'),
              Tab(text: '记录与分析'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _DailyScheduleView(
                  selectedDate: _selectedDate,
                  problems: widget.problems,
                  training: widget.training,
                  onDateChanged: (date) => setState(() {
                    _selectedDate =
                        DateTime(date.year, date.month, date.day, 4);
                  }),
                  onStart: widget.onStart,
                  onPause: widget.onPause,
                  onResume: widget.onResume,
                  onCancel: widget.onCancel,
                  onFinish: _finish,
                  onAddTasks: widget.onAddTasks,
                  onMoveTask: widget.onMoveTask,
                  onRemoveTask: widget.onRemoveTask,
                  onOpenProblem: widget.onOpenProblem,
                ),
                _TrainingListsView(
                  problems: widget.problems,
                  contests: widget.contests,
                  training: widget.training,
                  onStart: widget.onStart,
                  onOpenProblem: widget.onOpenProblem,
                  onSave: widget.onSaveList,
                  onDelete: widget.onDeleteList,
                ),
                _TrainingHistoryView(
                  problems: widget.problems,
                  attempts: widget.training.attempts,
                  analytics: widget.analytics,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _finish() async {
    final active = widget.training.activeAttempt;
    if (active == null) return;
    final result = await showDialog<TrainingFinishInput>(
      context: context,
      builder: (_) => _FinishAttemptDialog(
        elapsedSeconds: active.elapsedSeconds(DateTime.now()),
        lists: widget.training.lists.where((item) => !item.archived).toList(),
      ),
    );
    if (result != null) await widget.onFinish(result);
  }
}

class _DailyScheduleView extends StatelessWidget {
  const _DailyScheduleView({
    required this.selectedDate,
    required this.problems,
    required this.training,
    required this.onDateChanged,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    required this.onFinish,
    required this.onAddTasks,
    required this.onMoveTask,
    required this.onRemoveTask,
    required this.onOpenProblem,
  });

  final DateTime selectedDate;
  final List<ProblemRecord> problems;
  final TrainingStoreData training;
  final ValueChanged<DateTime> onDateChanged;
  final Future<void> Function(ProblemRecord problem, String? taskId) onStart;
  final Future<void> Function() onPause;
  final Future<void> Function() onResume;
  final Future<void> Function() onCancel;
  final Future<void> Function() onFinish;
  final Future<void> Function(Iterable<String> problemIds, String trainingDate)
      onAddTasks;
  final Future<void> Function(String taskId, String trainingDate) onMoveTask;
  final Future<void> Function(String taskId) onRemoveTask;
  final Future<void> Function(ProblemRecord problem) onOpenProblem;

  @override
  Widget build(BuildContext context) {
    final selectedKey = dateKey(selectedDate);
    final todayKey = trainingDateFor(DateTime.now());
    final tasks = training.tasks
        .where((item) => item.trainingDate == selectedKey)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final attempts = training.attempts
        .where((item) => trainingDateFor(item.endedAt) == selectedKey)
        .toList();
    final done =
        tasks.where((item) => item.status == DailyTaskStatus.done).length;
    final seconds = attempts.fold<int>(
      0,
      (sum, item) => sum + (item.durationSeconds ?? 0),
    );
    final active = training.activeAttempt;

    return ListView(
      key: const ValueKey('training-schedule-tab'),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('previous-training-date'),
              tooltip: '前一天',
              onPressed: () =>
                  onDateChanged(selectedDate.subtract(const Duration(days: 1))),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('pick-training-date'),
                onPressed: () => _pickDate(context),
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(_dateLabel(selectedDate, todayKey)),
              ),
            ),
            IconButton(
              key: const ValueKey('next-training-date'),
              tooltip: '后一天',
              onPressed: () =>
                  onDateChanged(selectedDate.add(const Duration(days: 1))),
              icon: const Icon(Icons.chevron_right),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: selectedKey == todayKey
                  ? null
                  : () => onDateChanged(trainingDayStartFor(DateTime.now())),
              child: const Text('回到今天'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              key: const ValueKey('add-schedule-tasks-button'),
              onPressed: () => _addTasks(context, selectedKey),
              icon: const Icon(Icons.playlist_add),
              label: const Text('添加安排'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 720
                ? (constraints.maxWidth - 30) / 4
                : (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Metric(width: width, label: '安排', value: '${tasks.length}'),
                _Metric(width: width, label: '已完成', value: '$done'),
                _Metric(width: width, label: '尝试', value: '${attempts.length}'),
                _Metric(
                    width: width,
                    label: '训练时间',
                    value: _durationLabel(seconds)),
              ],
            );
          },
        ),
        if (active != null) ...[
          const SizedBox(height: 12),
          _ActiveAttemptCard(
            active: active,
            problem: _problemById(problems, active.problemId),
            onPause: onPause,
            onResume: onResume,
            onCancel: () => _confirmCancel(context),
            onFinish: onFinish,
          ),
        ],
        const SizedBox(height: 14),
        Text(
          '日程任务',
          style: TextStyle(
            color: textPrimaryColor,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        if (tasks.isEmpty)
          AppEmptyState(
            icon: Icons.event_available_outlined,
            title: '这一天还没有安排',
            message: selectedKey == todayKey
                ? '按自己的节奏选择今天要做的题目。'
                : '可以提前安排，也可以补记过去的训练计划。',
          )
        else
          for (final task in tasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TaskRow(
                task: task,
                problem: _problemById(problems, task.problemId),
                activeTaskId: active?.taskId,
                hasActiveAttempt: active != null,
                onStart: onStart,
                onOpenProblem: onOpenProblem,
                onMove: () => _moveTask(context, task),
                onRemove: () => _removeTask(context, task),
              ),
            ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) onDateChanged(picked);
  }

  Future<void> _addTasks(BuildContext context, String selectedKey) async {
    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _ProblemPickerDialog(
        problems: problems,
        attempts: training.attempts,
        lists: training.lists,
      ),
    );
    if (selected != null && selected.isNotEmpty) {
      await onAddTasks(selected, selectedKey);
    }
  }

  Future<void> _moveTask(
    BuildContext context,
    DailyTrainingTask task,
  ) async {
    final initial = trainingDayStartFromKey(task.trainingDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && dateKey(picked) != task.trainingDate) {
      await onMoveTask(task.id, dateKey(picked));
    }
  }

  Future<void> _removeTask(
    BuildContext context,
    DailyTrainingTask task,
  ) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('移除日程任务？'),
            content: const Text('只会移除这条安排，题目和训练记录都会保留。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('移除'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) await onRemoveTask(task.id);
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('取消当前训练？'),
        content: const Text('本次计时不会保存为尝试记录，日程任务仍会保留。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('继续训练'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('取消训练'),
          ),
        ],
      ),
    );
    if (confirmed == true) await onCancel();
  }
}

class _Metric extends StatelessWidget {
  const _Metric(
      {required this.width, required this.label, required this.value});

  final double width;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: AppSurfaceCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: textSecondaryColor)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: textPrimaryColor,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveAttemptCard extends StatelessWidget {
  const _ActiveAttemptCard({
    required this.active,
    required this.problem,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    required this.onFinish,
  });

  final ActiveTrainingAttempt active;
  final ProblemRecord? problem;
  final Future<void> Function() onPause;
  final Future<void> Function() onResume;
  final Future<void> Function() onCancel;
  final Future<void> Function() onFinish;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      key: const ValueKey('active-training-card'),
      color: cardMutedColor,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: accentColor, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  problem?.title ?? '未知题目',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${active.isPaused ? '已暂停' : '训练中'} · ${_durationLabel(active.elapsedSeconds(DateTime.now()))}',
                  style: TextStyle(color: textSecondaryColor),
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('cancel-training-button'),
            tooltip: '取消训练',
            onPressed: onCancel,
            icon: const Icon(Icons.close),
          ),
          IconButton(
            key: const ValueKey('pause-training-button'),
            tooltip: active.isPaused ? '继续' : '暂停',
            onPressed: active.isPaused ? onResume : onPause,
            icon: Icon(active.isPaused ? Icons.play_arrow : Icons.pause),
          ),
          FilledButton.icon(
            key: const ValueKey('finish-training-button'),
            onPressed: onFinish,
            icon: const Icon(Icons.check),
            label: const Text('结束'),
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.problem,
    required this.activeTaskId,
    required this.hasActiveAttempt,
    required this.onStart,
    required this.onOpenProblem,
    required this.onMove,
    required this.onRemove,
  });

  final DailyTrainingTask task;
  final ProblemRecord? problem;
  final String? activeTaskId;
  final bool hasActiveAttempt;
  final Future<void> Function(ProblemRecord problem, String? taskId) onStart;
  final Future<void> Function(ProblemRecord problem) onOpenProblem;
  final Future<void> Function() onMove;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    final isDone = task.status == DailyTaskStatus.done;
    final isActive = activeTaskId == task.id;
    return AppSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(
            isDone
                ? Icons.check_circle
                : isActive
                    ? Icons.timelapse
                    : Icons.radio_button_unchecked,
            color: isDone || isActive ? accentColor : textSecondaryColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  problem?.title ?? '题目已不存在',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  isDone
                      ? '已完成'
                      : isActive
                          ? '正在训练'
                          : '待开始',
                  style: TextStyle(color: textSecondaryColor, fontSize: 12),
                ),
              ],
            ),
          ),
          if (problem != null)
            IconButton(
              tooltip: '打开题目',
              onPressed: () => onOpenProblem(problem!),
              icon: const Icon(Icons.open_in_new),
            ),
          if (!isDone && !isActive && problem != null)
            FilledButton.tonalIcon(
              key: ValueKey('start-training-${task.id}'),
              onPressed:
                  hasActiveAttempt ? null : () => onStart(problem!, task.id),
              icon: const Icon(Icons.play_arrow),
              label: const Text('开始'),
            ),
          PopupMenuButton<String>(
            tooltip: '更多操作',
            enabled: !isActive,
            onSelected: (value) {
              if (value == 'move') onMove();
              if (value == 'remove') onRemove();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'move', child: Text('改期')),
              PopupMenuItem(value: 'remove', child: Text('移除')),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrainingListsView extends StatelessWidget {
  const _TrainingListsView({
    required this.problems,
    required this.contests,
    required this.training,
    required this.onStart,
    required this.onOpenProblem,
    required this.onSave,
    required this.onDelete,
  });

  final List<ProblemRecord> problems;
  final List<ContestRecord> contests;
  final TrainingStoreData training;
  final Future<void> Function(ProblemRecord problem, String? taskId) onStart;
  final Future<void> Function(ProblemRecord problem) onOpenProblem;
  final Future<void> Function(TrainingList list) onSave;
  final Future<void> Function(String id) onDelete;

  @override
  Widget build(BuildContext context) {
    final visible = training.lists.where((item) => !item.archived).toList();
    return ListView(
      key: const ValueKey('training-lists-tab'),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            key: const ValueKey('add-training-list-button'),
            onPressed: () => _openEditor(context),
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('新建题单'),
          ),
        ),
        const SizedBox(height: 10),
        for (final list in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppSurfaceCard(
              child: InkWell(
                onTap: () => _openList(context, list),
                child: Row(
                  children: [
                    Icon(
                      list.isDefault
                          ? Icons.star_outline
                          : Icons.folder_outlined,
                      color: accentColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  list.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: textPrimaryColor,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              if (list.isDefault) ...[
                                const SizedBox(width: 8),
                                const Pill(label: '默认'),
                              ],
                            ],
                          ),
                          Text(
                            _listSubtitle(list),
                            style: TextStyle(color: textSecondaryColor),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '打开题单',
                      onPressed: () => _openList(context, list),
                      icon: const Icon(Icons.chevron_right),
                    ),
                    IconButton(
                      tooltip: '编辑题单',
                      onPressed: () => _openEditor(context, initial: list),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    if (!list.isDefault)
                      IconButton(
                        tooltip: '删除题单',
                        onPressed: () => _confirmDelete(context, list),
                        icon: const Icon(Icons.delete_outline),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _listSubtitle(TrainingList list) {
    final attemptsByProblem = _latestAttempts(training.attempts);
    var attempted = 0;
    var ac = 0;
    for (final id in list.problemIds) {
      final attempt = attemptsByProblem[id];
      if (attempt != null) attempted += 1;
      if (attempt?.result == AttemptResult.ac) ac += 1;
    }
    return '${_listTypeLabel(list.type)} · $attempted/${list.problemIds.length} 已尝试 · AC $ac';
  }

  Future<void> _openList(BuildContext context, TrainingList list) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _TrainingListDetailDialog(
        list: list,
        problems: problems,
        attempts: training.attempts,
        hasActiveAttempt: training.activeAttempt != null,
        onStart: onStart,
        onOpenProblem: onOpenProblem,
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context, {
    TrainingList? initial,
  }) async {
    final result = await showDialog<TrainingList>(
      context: context,
      builder: (_) => _TrainingListDialog(
        problems: problems
            .where(
                (item) => item.workflowStatus != ProblemWorkflowStatus.archived)
            .toList(),
        attempts: training.attempts,
        lists: training.lists,
        contests: contests,
        initial: initial,
      ),
    );
    if (result != null) await onSave(result);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TrainingList list,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除题单？'),
        content: Text('题目和训练记录不会删除，仅移除题单“${list.title}”。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) await onDelete(list.id);
  }
}

class _TrainingListDetailDialog extends StatelessWidget {
  const _TrainingListDetailDialog({
    required this.list,
    required this.problems,
    required this.attempts,
    required this.hasActiveAttempt,
    required this.onStart,
    required this.onOpenProblem,
  });

  final TrainingList list;
  final List<ProblemRecord> problems;
  final List<TrainingAttempt> attempts;
  final bool hasActiveAttempt;
  final Future<void> Function(ProblemRecord problem, String? taskId) onStart;
  final Future<void> Function(ProblemRecord problem) onOpenProblem;

  @override
  Widget build(BuildContext context) {
    final latest = _latestAttempts(attempts);
    final listProblems = [
      for (final id in list.problemIds)
        if (_problemById(problems, id) case final problem?) problem,
    ];
    final counts = <AttemptResult, int>{};
    for (final problem in listProblems) {
      final result = latest[problem.id]?.result;
      if (result != null) counts[result] = (counts[result] ?? 0) + 1;
    }
    return AlertDialog(
      key: const ValueKey('training-list-detail-dialog'),
      title: Text(list.title),
      content: SizedBox(
        width: 680,
        height: (MediaQuery.sizeOf(context).height - 200)
            .clamp(320.0, 520.0)
            .toDouble(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Pill(label: '${listProblems.length} 题'),
                for (final entry in counts.entries)
                  Pill(
                      label:
                          '${_attemptResultLabel(entry.key)} ${entry.value}'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: listProblems.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.folder_open_outlined,
                      title: '题单中还没有题目',
                      message: '编辑题单后即可从这里开始训练。',
                    )
                  : ListView.separated(
                      itemCount: listProblems.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final problem = listProblems[index];
                        final attempt = latest[problem.id];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            child: Text('${index + 1}'),
                          ),
                          title: Text(
                            problem.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${problemPlatformLabel(problem.platform)} · ${attempt == null ? '未尝试' : _attemptResultLabel(attempt.result)}',
                          ),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                tooltip: '打开题目',
                                onPressed: () => onOpenProblem(problem),
                                icon: const Icon(Icons.open_in_new),
                              ),
                              IconButton(
                                tooltip: '开始训练',
                                onPressed: hasActiveAttempt
                                    ? null
                                    : () {
                                        Navigator.pop(context);
                                        onStart(problem, null);
                                      },
                                icon: const Icon(Icons.play_arrow),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

class _TrainingHistoryView extends StatelessWidget {
  const _TrainingHistoryView({
    required this.problems,
    required this.attempts,
    required this.analytics,
  });

  final List<ProblemRecord> problems;
  final List<TrainingAttempt> attempts;
  final TrainingAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final mistakes = analytics.mistakeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ListView(
      key: const ValueKey('training-history-tab'),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 600
                ? (constraints.maxWidth - 20) / 3
                : constraints.maxWidth;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Metric(
                  width: width,
                  label: '今日尝试',
                  value: '${analytics.attemptsToday}',
                ),
                _Metric(
                  width: width,
                  label: '今日专注',
                  value: _durationLabel(analytics.focusSecondsToday),
                ),
                _Metric(
                  width: width,
                  label: '独立 AC',
                  value: '${(analytics.independentAcRate * 100).round()}%',
                ),
              ],
            );
          },
        ),
        if (mistakes.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            '常见错误',
            style: TextStyle(
              color: textPrimaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in mistakes.take(8))
                Pill(label: '${_mistakeLabel(entry.key)} ${entry.value}'),
            ],
          ),
        ],
        if (analytics.repeatedFailureProblemIds.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            '重复失败题',
            style: TextStyle(
              color: textPrimaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in analytics.repeatedFailureProblemIds.take(10))
                Pill(label: _problemById(problems, id)?.title ?? '已删除题目'),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Text(
          '尝试记录',
          style: TextStyle(
            color: textPrimaryColor,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        if (attempts.isEmpty)
          const AppEmptyState(
            icon: Icons.history,
            title: '还没有训练记录',
            message: '开始一道题并保存结果后，会在这里保留完整记录。',
          )
        else
          for (final attempt in attempts.take(100))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AttemptRecordCard(
                attempt: attempt,
                problem: _problemById(problems, attempt.problemId),
              ),
            ),
      ],
    );
  }
}

class _AttemptRecordCard extends StatelessWidget {
  const _AttemptRecordCard({required this.attempt, required this.problem});

  final TrainingAttempt attempt;
  final ProblemRecord? problem;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                attempt.result == AttemptResult.ac
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
                color: attempt.result == AttemptResult.ac
                    ? accentColor
                    : dangerColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  problem?.title ?? '已删除题目',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Pill(label: _attemptResultLabel(attempt.result)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_dateTimeLabel(attempt.startedAt)} - ${_timeLabel(attempt.endedAt)} · ${attempt.durationSeconds == null ? '耗时未知' : _durationLabel(attempt.durationSeconds!)} · ${_assistanceLabel(attempt.assistance)}',
            style: TextStyle(color: textSecondaryColor, fontSize: 12),
          ),
          if (attempt.mistakes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final mistake in attempt.mistakes)
                  Pill(label: _mistakeLabel(mistake)),
              ],
            ),
          ],
          if (attempt.reflection.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              attempt.reflection,
              style: TextStyle(color: textPrimaryColor, height: 1.45),
            ),
          ],
        ],
      ),
    );
  }
}

class _FinishAttemptDialog extends StatefulWidget {
  const _FinishAttemptDialog({
    required this.elapsedSeconds,
    required this.lists,
  });

  final int elapsedSeconds;
  final List<TrainingList> lists;

  @override
  State<_FinishAttemptDialog> createState() => _FinishAttemptDialogState();
}

class _FinishAttemptDialogState extends State<_FinishAttemptDialog> {
  final _reflection = TextEditingController();
  AttemptResult _result = AttemptResult.ac;
  AssistanceLevel _assistance = AssistanceLevel.none;
  final Set<MistakeCategory> _mistakes = {};
  bool _favorite = false;
  String? _favoriteListId;

  @override
  void initState() {
    super.initState();
    _favoriteListId =
        widget.lists.where((item) => item.isDefault).firstOrNull?.id ??
            widget.lists.firstOrNull?.id;
  }

  @override
  void dispose() {
    _reflection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('finish-attempt-dialog'),
      title: const Text('记录本次训练'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardMutedColor,
                  borderRadius: BorderRadius.circular(appRadiusControl),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, color: accentColor),
                    const SizedBox(width: 8),
                    Text(
                      '自动计时 ${_durationLabel(widget.elapsedSeconds)}',
                      style: TextStyle(
                        color: textPrimaryColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<AttemptResult>(
                      key: const ValueKey('attempt-result-field'),
                      initialValue: _result,
                      decoration: const InputDecoration(labelText: '结果'),
                      items: [
                        for (final result in AttemptResult.values)
                          DropdownMenuItem(
                            value: result,
                            child: Text(_attemptResultLabel(result)),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _result = value ?? AttemptResult.ac),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<AssistanceLevel>(
                      key: const ValueKey('attempt-assistance-field'),
                      initialValue: _assistance,
                      decoration: const InputDecoration(labelText: '辅助程度'),
                      items: [
                        for (final value in AssistanceLevel.values)
                          DropdownMenuItem(
                            value: value,
                            child: Text(_assistanceLabel(value)),
                          ),
                      ],
                      onChanged: (value) => setState(
                        () => _assistance = value ?? AssistanceLevel.none,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('错误类型', style: TextStyle(color: textSecondaryColor)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final mistake in MistakeCategory.values)
                    FilterChip(
                      label: Text(_mistakeLabel(mistake)),
                      selected: _mistakes.contains(mistake),
                      onSelected: (selected) => setState(() {
                        selected
                            ? _mistakes.add(mistake)
                            : _mistakes.remove(mistake);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('attempt-reflection-field'),
                controller: _reflection,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(labelText: '复盘心得'),
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                key: const ValueKey('favorite-attempt-checkbox'),
                contentPadding: EdgeInsets.zero,
                value: _favorite,
                title: const Text('收藏此题'),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: widget.lists.isEmpty
                    ? null
                    : (value) => setState(() => _favorite = value ?? false),
              ),
              if (_favorite)
                DropdownButtonFormField<String>(
                  key: const ValueKey('favorite-list-field'),
                  initialValue: _favoriteListId,
                  decoration: const InputDecoration(labelText: '收藏到'),
                  items: [
                    for (final list in widget.lists)
                      DropdownMenuItem(
                        value: list.id,
                        child: Text(list.title),
                      ),
                  ],
                  onChanged: (value) => setState(() => _favoriteListId = value),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('save-attempt-button'),
          onPressed: _save,
          child: const Text('保存记录'),
        ),
      ],
    );
  }

  void _save() {
    Navigator.pop(
      context,
      TrainingFinishInput(
        result: _result,
        assistance: _assistance,
        mistakes: _mistakes.toList(),
        reflection: _reflection.text,
        favoriteListId: _favorite ? _favoriteListId : null,
      ),
    );
  }
}

class _TrainingListDialog extends StatefulWidget {
  const _TrainingListDialog({
    required this.problems,
    required this.attempts,
    required this.lists,
    required this.contests,
    this.initial,
  });

  final List<ProblemRecord> problems;
  final List<TrainingAttempt> attempts;
  final List<TrainingList> lists;
  final List<ContestRecord> contests;
  final TrainingList? initial;

  @override
  State<_TrainingListDialog> createState() => _TrainingListDialogState();
}

class _TrainingListDialogState extends State<_TrainingListDialog> {
  late final TextEditingController _title;
  late TrainingListType _type;
  late Set<String> _selected;
  String? _contestId;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initial?.title ?? '');
    _type = widget.initial?.type ?? TrainingListType.custom;
    _selected = {...widget.initial?.problemIds ?? const []};
    _contestId = widget.initial?.contestId;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('training-list-dialog'),
      title: Text(widget.initial == null ? '新建题单' : '编辑题单'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('training-list-title-field'),
                    controller: _title,
                    decoration: const InputDecoration(labelText: '题单名称'),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<TrainingListType>(
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: '类型'),
                    items: [
                      for (final type in TrainingListType.values)
                        DropdownMenuItem(
                          value: type,
                          child: Text(_listTypeLabel(type)),
                        ),
                    ],
                    onChanged: (value) => setState(
                      () => _type = value ?? TrainingListType.custom,
                    ),
                  ),
                ),
              ],
            ),
            if (_type == TrainingListType.contest) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                key: const ValueKey('training-list-contest-field'),
                initialValue: _contestId,
                decoration: const InputDecoration(labelText: '关联比赛'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('不关联比赛'),
                  ),
                  for (final contest in widget.contests)
                    DropdownMenuItem<String?>(
                      value: contest.id,
                      child: Text(
                        '${contest.date} · ${contest.title}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _contestId = value),
              ),
            ],
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.checklist_outlined),
              title: Text('已选择 ${_selected.length} 道题'),
              subtitle: const Text('可按结果、平台、状态、标签和题单筛选'),
              trailing: FilledButton.tonal(
                key: const ValueKey('choose-list-problems-button'),
                onPressed: _chooseProblems,
                child: const Text('选择题目'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('save-training-list-button'),
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }

  Future<void> _chooseProblems() async {
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (_) => _ProblemPickerDialog(
        problems: widget.problems,
        attempts: widget.attempts,
        lists: widget.lists,
        initialSelection: _selected,
      ),
    );
    if (result != null) setState(() => _selected = result);
  }

  void _save() {
    if (_title.text.trim().isEmpty) return;
    final initial = widget.initial;
    Navigator.pop(
      context,
      initial == null
          ? TrainingList.create(
              title: _title.text,
              type: _type,
              problemIds: _selected.toList(),
              contestId: _type == TrainingListType.contest ? _contestId : null,
            )
          : initial.copyWith(
              title: _title.text,
              type: _type,
              problemIds: _selected.toList(),
              contestId: _type == TrainingListType.contest ? _contestId : null,
              clearContestId: _type != TrainingListType.contest,
            ),
    );
  }
}

enum _ResultFilter { any, unattempted, ac, wa, tle, re, gaveUp, skipped }

class _ProblemPickerDialog extends StatefulWidget {
  const _ProblemPickerDialog({
    required this.problems,
    required this.attempts,
    required this.lists,
    this.initialSelection = const {},
  });

  final List<ProblemRecord> problems;
  final List<TrainingAttempt> attempts;
  final List<TrainingList> lists;
  final Set<String> initialSelection;

  @override
  State<_ProblemPickerDialog> createState() => _ProblemPickerDialogState();
}

class _ProblemPickerDialogState extends State<_ProblemPickerDialog> {
  final _query = TextEditingController();
  late Set<String> _selected;
  ProblemPlatform? _platform;
  ProblemWorkflowStatus? _workflow;
  _ResultFilter _result = _ResultFilter.any;
  String? _tag;
  String? _listId;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initialSelection};
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final latest = _latestAttempts(widget.attempts);
    final tags = widget.problems.expand((item) => item.tags).toSet().toList()
      ..sort();
    final visible = widget.problems.where((problem) {
      if (problem.workflowStatus == ProblemWorkflowStatus.archived) {
        return false;
      }
      final query = _query.text.trim().toLowerCase();
      if (query.isNotEmpty &&
          ![problem.title, problem.url, ...problem.tags]
              .join(' ')
              .toLowerCase()
              .contains(query)) {
        return false;
      }
      if (_platform != null && problem.platform != _platform) return false;
      if (_workflow != null && problem.workflowStatus != _workflow) {
        return false;
      }
      if (_tag != null && !problem.tags.contains(_tag)) return false;
      if (_listId != null) {
        final list =
            widget.lists.where((item) => item.id == _listId).firstOrNull;
        if (list == null || !list.problemIds.contains(problem.id)) return false;
      }
      return _matchesResult(_result, latest[problem.id]?.result);
    }).toList();

    return AlertDialog(
      key: const ValueKey('problem-picker-dialog'),
      title: const Text('选择题目'),
      content: SizedBox(
        width: 760,
        height: (MediaQuery.sizeOf(context).height - 200)
            .clamp(320.0, 560.0)
            .toDouble(),
        child: Column(
          children: [
            TextField(
              key: const ValueKey('picker-query-field'),
              controller: _query,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜索标题、链接或标签',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<ProblemPlatform?>(
                    key: const ValueKey('picker-platform-filter'),
                    isExpanded: true,
                    initialValue: _platform,
                    decoration: const InputDecoration(labelText: '平台'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('全部平台')),
                      for (final value in ProblemPlatform.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(problemPlatformLabel(value)),
                        ),
                    ],
                    onChanged: (value) => setState(() => _platform = value),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<ProblemWorkflowStatus?>(
                    key: const ValueKey('picker-workflow-filter'),
                    isExpanded: true,
                    initialValue: _workflow,
                    decoration: const InputDecoration(labelText: '题目状态'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('全部状态')),
                      for (final value in ProblemWorkflowStatus.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(problemWorkflowStatusLabel(value)),
                        ),
                    ],
                    onChanged: (value) => setState(() => _workflow = value),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<_ResultFilter>(
                    key: const ValueKey('picker-result-filter'),
                    isExpanded: true,
                    initialValue: _result,
                    decoration: const InputDecoration(labelText: '最近结果'),
                    items: [
                      for (final value in _ResultFilter.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(_resultFilterLabel(value)),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _result = value ?? _ResultFilter.any),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String?>(
                    key: const ValueKey('picker-tag-filter'),
                    isExpanded: true,
                    initialValue: _tag,
                    decoration: const InputDecoration(labelText: '标签'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('全部标签')),
                      for (final value in tags)
                        DropdownMenuItem(value: value, child: Text(value)),
                    ],
                    onChanged: (value) => setState(() => _tag = value),
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<String?>(
                    key: const ValueKey('picker-list-filter'),
                    isExpanded: true,
                    initialValue: _listId,
                    decoration: const InputDecoration(labelText: '所属题单'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('全部题单')),
                      for (final list
                          in widget.lists.where((item) => !item.archived))
                        DropdownMenuItem(
                            value: list.id, child: Text(list.title)),
                    ],
                    onChanged: (value) => setState(() => _listId = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '已选择 ${_selected.length} 道 · 当前 ${visible.length} 道',
                  style: TextStyle(color: textSecondaryColor),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() {
                    _selected.addAll(visible.map((item) => item.id));
                  }),
                  child: const Text('全选当前'),
                ),
                TextButton(
                  onPressed: () => setState(() => _selected.clear()),
                  child: const Text('清空'),
                ),
              ],
            ),
            Expanded(
              child: visible.isEmpty
                  ? const Center(child: Text('没有符合条件的题目'))
                  : ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final problem = visible[index];
                        final attempt = latest[problem.id];
                        return CheckboxListTile(
                          value: _selected.contains(problem.id),
                          title: Text(
                            problem.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${problemPlatformLabel(problem.platform)} · ${problemWorkflowStatusLabel(problem.workflowStatus)} · ${attempt == null ? '未尝试' : _attemptResultLabel(attempt.result)}',
                          ),
                          onChanged: (selected) => setState(() {
                            selected == true
                                ? _selected.add(problem.id)
                                : _selected.remove(problem.id);
                          }),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('confirm-problem-selection'),
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('确认选择'),
        ),
      ],
    );
  }
}

ProblemRecord? _problemById(List<ProblemRecord> problems, String id) {
  for (final problem in problems) {
    if (problem.id == id) return problem;
  }
  return null;
}

Map<String, TrainingAttempt> _latestAttempts(List<TrainingAttempt> attempts) {
  final result = <String, TrainingAttempt>{};
  for (final attempt in attempts) {
    final current = result[attempt.problemId];
    if (current == null || attempt.endedAt.isAfter(current.endedAt)) {
      result[attempt.problemId] = attempt;
    }
  }
  return result;
}

bool _matchesResult(_ResultFilter filter, AttemptResult? result) {
  return switch (filter) {
    _ResultFilter.any => true,
    _ResultFilter.unattempted => result == null,
    _ResultFilter.ac => result == AttemptResult.ac,
    _ResultFilter.wa => result == AttemptResult.wa,
    _ResultFilter.tle => result == AttemptResult.tle,
    _ResultFilter.re => result == AttemptResult.re,
    _ResultFilter.gaveUp => result == AttemptResult.gaveUp,
    _ResultFilter.skipped => result == AttemptResult.skipped,
  };
}

String _resultFilterLabel(_ResultFilter value) => switch (value) {
      _ResultFilter.any => '全部结果',
      _ResultFilter.unattempted => '未尝试',
      _ResultFilter.ac => 'AC',
      _ResultFilter.wa => 'WA',
      _ResultFilter.tle => 'TLE',
      _ResultFilter.re => 'RE',
      _ResultFilter.gaveUp => '放弃',
      _ResultFilter.skipped => '跳过',
    };

String _dateLabel(DateTime date, String todayKey) {
  final key = dateKey(date);
  final suffix = key == todayKey ? ' · 今天' : '';
  return '$key$suffix';
}

String _dateTimeLabel(DateTime value) {
  final local = value.toLocal();
  return '${dateKey(local)} ${_timeLabel(local)}';
}

String _timeLabel(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _durationLabel(int seconds) {
  final duration = Duration(seconds: seconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final secs = duration.inSeconds.remainder(60);
  return hours > 0
      ? '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}'
      : '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
}

String _listTypeLabel(TrainingListType type) => switch (type) {
      TrainingListType.custom => '自定义',
      TrainingListType.topic => '专题',
      TrainingListType.contest => '比赛补题',
    };

String _attemptResultLabel(AttemptResult result) => switch (result) {
      AttemptResult.ac => 'AC',
      AttemptResult.wa => 'WA',
      AttemptResult.tle => 'TLE',
      AttemptResult.re => 'RE',
      AttemptResult.gaveUp => '放弃',
      AttemptResult.skipped => '跳过',
    };

String _assistanceLabel(AssistanceLevel value) => switch (value) {
      AssistanceLevel.none => '独立完成',
      AssistanceLevel.hint => '看过提示',
      AssistanceLevel.editorial => '看过题解',
    };

String _mistakeLabel(MistakeCategory value) => switch (value) {
      MistakeCategory.idea => '思路',
      MistakeCategory.implementation => '实现',
      MistakeCategory.complexity => '复杂度',
      MistakeCategory.edgeCase => '边界',
      MistakeCategory.math => '数学',
      MistakeCategory.reading => '读题',
      MistakeCategory.template => '模板',
      MistakeCategory.timeManagement => '时间管理',
      MistakeCategory.other => '其他',
    };

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
