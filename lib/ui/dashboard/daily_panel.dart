part of '../../main.dart';

class _DailyPanel extends StatelessWidget {
  const _DailyPanel({required this.state});

  final OjState state;

  @override
  Widget build(BuildContext context) {
    final summary = state.todaySummary;
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
            children: [
              const Expanded(
                child: Text(
                  '每日总结',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              _Pill(label: summary.date),
            ],
          ),
          const SizedBox(height: 10),
          if (summary.deltas.isEmpty)
            const Text('暂无今日快照', style: TextStyle(color: _textSecondaryColor))
          else
            ...supportedOjs.map((meta) {
              final delta = summary.deltas[meta.id];
              if (delta == null) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(child: Text(meta.name)),
                    Text('+$delta'),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
