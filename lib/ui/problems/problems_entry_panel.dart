import 'package:flutter/material.dart';
import '../../models/problem_record.dart';
import '../app_theme.dart';
import '../shared/workspace_entry_card.dart';

class ProblemsEntryPanel extends StatelessWidget {
  const ProblemsEntryPanel(
      {super.key, required this.problems, required this.onOpen});
  final List<ProblemRecord> problems;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final pending = problems
        .where((p) =>
            p.workflowStatus == ProblemWorkflowStatus.backlog ||
            p.workflowStatus == ProblemWorkflowStatus.active ||
            p.workflowStatus == ProblemWorkflowStatus.review)
        .length;
    final mastered = problems
        .where((p) => p.workflowStatus == ProblemWorkflowStatus.mastered)
        .length;
    return WorkspaceEntryCard(
      title: '补题 / 错题本',
      icon: Icons.bookmark_border,
      description: '收集值得再做的题，再回到训练中。',
      onOpen: onOpen,
      openKey: const ValueKey('problems-entry-button'),
      child: Row(children: [
        Text('$pending 待处理', style: TextStyle(color: accentColor)),
        const SizedBox(width: 20),
        Text('$mastered 已掌握', style: Theme.of(context).textTheme.bodySmall)
      ]),
    );
  }
}
