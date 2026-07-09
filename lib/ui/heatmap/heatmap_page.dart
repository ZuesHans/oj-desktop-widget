import 'package:flutter/material.dart';

import '../../services/heatmap_service.dart';
import '../app_theme.dart';
import '../shared/app_surface_card.dart';
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
      padding:
          const EdgeInsets.fromLTRB(appSpace5, appSpace3, appSpace5, appSpace5),
      children: [
        AppSurfaceCard(
          child: Row(
            children: [
              if (showBackButton) ...[
                IconButton(
                  key: const ValueKey('heatmap-back-button'),
                  tooltip: '返回',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: appSpace1),
              ],
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(appRadiusControl),
                  border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                ),
                child: Icon(Icons.calendar_view_week, color: accentColor),
              ),
              const SizedBox(width: appSpace3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '热力图',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textPrimaryColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '连续 ${summary.currentStreak} 天 · 活跃 ${summary.activeDays} 天 · 累计 +${summary.totalDelta}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textSecondaryColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: appSpace2),
              IconButton(
                key: const ValueKey('heatmap-export-data-button'),
                tooltip: '导出备份',
                onPressed: onExport,
                color: accentColor,
                icon: const Icon(Icons.download),
              ),
              IconButton(
                key: const ValueKey('heatmap-import-backup-button'),
                tooltip: '导入备份',
                onPressed: onImport,
                color: accentColor,
                icon: const Icon(Icons.upload_file),
              ),
            ],
          ),
        ),
        const SizedBox(height: appSpace3),
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
