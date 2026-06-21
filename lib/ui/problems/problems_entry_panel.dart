part of '../../main.dart';

class _ProblemsEntryPanel extends StatelessWidget {
  const _ProblemsEntryPanel({
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.assignment_outlined, color: _accentColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '补题 / 错题本',
                  style: TextStyle(
                    color: _textPrimaryColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '待处理 $todo · 已 AC $accepted · 共 ${problems.length}',
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: _textSecondaryColor, fontSize: 12),
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
