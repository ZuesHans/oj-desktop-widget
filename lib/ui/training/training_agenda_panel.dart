import 'package:flutter/material.dart';

import '../../core/time.dart';
import '../../models/problem_record.dart';
import '../../models/training.dart';
import '../app_theme.dart';
import '../shared/workspace_entry_card.dart';

class TrainingAgendaPanel extends StatelessWidget {
  const TrainingAgendaPanel(
      {super.key,
      required this.training,
      required this.problems,
      required this.onOpen,
      required this.onStart});

  final TrainingStoreData training;
  final List<ProblemRecord> problems;
  final VoidCallback onOpen;
  final void Function(ProblemRecord, String taskId) onStart;

  @override
  Widget build(BuildContext context) {
    final tasks = training.tasks
        .where((task) => task.trainingDate == trainingDateFor(DateTime.now()))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final pending = tasks
        .where((task) =>
            task.status != DailyTaskStatus.done &&
            task.status != DailyTaskStatus.skipped)
        .toList();
    return WorkspaceEntryCard(
      title: '今日训练',
      icon: Icons.checklist_outlined,
      description: tasks.isEmpty
          ? '从题库选几道题，按自己的节奏开始。'
          : '${tasks.length - pending.length} / ${tasks.length} 项已处理 · 留出时间思考与复盘',
      onOpen: onOpen,
      openKey: const ValueKey('open-todo-agenda'),
      actions: [
        OutlinedButton.icon(
            key: const ValueKey('todo-entry-button'),
            onPressed: onOpen,
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: const Text('待办事项'))
      ],
      child: tasks.isEmpty
          ? null
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final task in pending.take(3)) ...[
                Builder(builder: (context) {
                  final problem =
                      problems.where((p) => p.id == task.problemId).firstOrNull;
                  return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(children: [
                        Icon(Icons.radio_button_unchecked,
                            size: 18, color: borderColor),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text(problem?.title ?? '题目已归档或移除',
                                maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        TextButton(
                            onPressed: problem == null ||
                                    training.activeAttempt != null
                                ? null
                                : () => onStart(problem, task.id),
                            child: const Text('开始')),
                      ]));
                }),
              ],
              if (pending.isEmpty && tasks.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('今天的安排已完成，去看看训练记录吧。',
                        style: Theme.of(context).textTheme.bodySmall)),
            ]),
    );
  }
}
