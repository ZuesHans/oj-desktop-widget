import 'package:flutter/material.dart';

import '../../services/heatmap_service.dart';
import '../app_theme.dart';
import '../shared/app_surface_card.dart';
import '../shared/app_page_header.dart';
import 'heatmap_dialog.dart';
import 'heatmap_formatters.dart';

class HeatmapPage extends StatelessWidget {
  const HeatmapPage({
    super.key,
    required this.summary,
    required this.onBack,
    required this.onExport,
    required this.onImport,
    this.showBackButton = true,
  });

  final HeatmapSummary summary;
  final VoidCallback onBack;
  final VoidCallback onExport;
  final VoidCallback onImport;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('heatmap-page'),
      padding: const EdgeInsets.all(24),
      children: [
        AppPageHeader(
          title: '热力图',
          subtitle: '每一天的积累，都在这里留下痕迹。',
          leading: showBackButton
              ? IconButton(
                  key: const ValueKey('heatmap-back-button'),
                  tooltip: '返回',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back))
              : null,
          actions: [
            IconButton(
                key: const ValueKey('heatmap-export-data-button'),
                tooltip: '导出备份',
                onPressed: onExport,
                icon: const Icon(Icons.download_outlined)),
            IconButton(
                key: const ValueKey('heatmap-import-backup-button'),
                tooltip: '导入备份',
                onPressed: onImport,
                icon: const Icon(Icons.upload_file_outlined)),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: appSpace2,
          runSpacing: appSpace2,
          children: [
            HeatmapStat(label: '当前连续', value: '${summary.currentStreak} 天'),
            HeatmapStat(label: '最长连续', value: '${summary.longestStreak} 天'),
            HeatmapStat(label: '活跃天数', value: '${summary.activeDays}'),
            HeatmapStat(label: '累计新增', value: '+${summary.totalDelta}'),
          ],
        ),
        const SizedBox(height: appSpace5),
        AppSurfaceCard(
          padding: const EdgeInsets.all(appSpace4),
          child: HeatmapGrid(days: summary.days),
        ),
      ],
    );
  }
}
