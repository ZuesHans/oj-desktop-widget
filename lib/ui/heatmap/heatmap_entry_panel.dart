import 'package:flutter/material.dart';
import '../../services/heatmap_service.dart';
import '../app_theme.dart';
import '../shared/workspace_entry_card.dart';

class HeatmapEntryPanel extends StatelessWidget {
  const HeatmapEntryPanel(
      {super.key,
      required this.summary,
      required this.onOpen,
      required this.onExport,
      required this.onImport});
  final HeatmapSummary summary;
  final VoidCallback onOpen;
  final VoidCallback onExport;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) => WorkspaceEntryCard(
        title: '热力图',
        icon: Icons.calendar_view_week,
        description: '从每日记录里，看见自己的训练节奏。',
        onOpen: onOpen,
        openKey: const ValueKey('heatmap-entry-button'),
        actions: [
          TextButton.icon(
              key: const ValueKey('export-data-button'),
              onPressed: onExport,
              icon: const Icon(Icons.download_outlined, size: 16),
              label: const Text('导出备份')),
          TextButton.icon(
              key: const ValueKey('import-backup-button'),
              onPressed: onImport,
              icon: const Icon(Icons.upload_file_outlined, size: 16),
              label: const Text('导入备份')),
        ],
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LayoutBuilder(builder: (context, constraints) {
            final days =
                summary.days.reversed.take(70).toList().reversed.toList();
            final size =
                ((constraints.maxWidth - 13 * 4) / 14).clamp(6.0, 13.0);
            return SizedBox(
                width: 14 * size + 13 * 4,
                child: Wrap(spacing: 4, runSpacing: 4, children: [
                  for (final day in days)
                    Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                            color: heatmapLevelColors[day.delta == 0
                                ? 0
                                : day.delta < 3
                                    ? 1
                                    : day.delta < 6
                                        ? 2
                                        : day.delta < 10
                                            ? 3
                                            : 4],
                            borderRadius: BorderRadius.circular(2))),
                ]));
          }),
          const SizedBox(height: 10),
          Text(
              '当前连续 ${summary.currentStreak} 天 · 最长 ${summary.longestStreak} 天',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
}
