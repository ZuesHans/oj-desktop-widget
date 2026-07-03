import 'package:flutter/material.dart';

import '../../models/problem_record.dart';
import '../app_theme.dart';

class ProblemsEntryPanel extends StatelessWidget {
  const ProblemsEntryPanel({
    super.key,
    required this.problems,
    required this.onOpen,
  });

  final List<ProblemRecord> problems;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final todo = problems
        .where((problem) =>
            problem.status == ProblemStatus.TODO ||
            problem.status == ProblemStatus.REVIEW)
        .length;
    final accepted =
        problems.where((problem) => problem.status == ProblemStatus.AC).length;
    final subtitle = todo == 0
        ? '已 AC $accepted · 共 ${problems.length}'
        : '待处理 $todo · 已 AC $accepted · 共 ${problems.length}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: (todo == 0 ? accentColor : dangerColor)
                  .withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (todo == 0 ? accentColor : dangerColor)
                    .withValues(alpha: 0.18),
              ),
            ),
            child: Icon(
              todo == 0 ? Icons.check_circle_outline : Icons.assignment_late,
              color: todo == 0 ? accentColor : dangerColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '补题 / 错题本',
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: textSecondaryColor, fontSize: 12),
                ),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            key: const ValueKey('problems-entry-button'),
            onPressed: onOpen,
            icon: const Icon(Icons.list_alt, size: 18),
            label: const Text('打开'),
          ),
        ],
      ),
    );
  }
}
