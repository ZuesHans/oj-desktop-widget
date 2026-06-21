part of '../../main.dart';

class HeatmapPage extends StatelessWidget {
  const HeatmapPage({
    super.key,
    required this.summary,
    required this.onBack,
    required this.onExport,
    required this.onImport,
  });

  final HeatmapSummary summary;
  final VoidCallback onBack;
  final VoidCallback onExport;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('heatmap-page'),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('heatmap-back-button'),
              tooltip: '返回',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                '热力图',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _textPrimaryColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('heatmap-export-data-button'),
              tooltip: 'Export Backup',
              onPressed: onExport,
              color: _accentColor,
              icon: const Icon(Icons.download),
            ),
            IconButton(
              key: const ValueKey('heatmap-import-backup-button'),
              tooltip: 'Import Backup',
              onPressed: onImport,
              color: _accentColor,
              icon: const Icon(Icons.upload_file),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _HeatmapStat(label: '当前连续', value: '${summary.currentStreak} 天'),
            _HeatmapStat(label: '最长连续', value: '${summary.longestStreak} 天'),
            _HeatmapStat(label: '活跃天数', value: '${summary.activeDays}'),
            _HeatmapStat(label: '累计新增', value: '+${summary.totalDelta}'),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _borderColor),
          ),
          child: _HeatmapGrid(days: summary.days),
        ),
      ],
    );
  }
}
