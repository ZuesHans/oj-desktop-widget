import 'package:flutter/material.dart';

import '../../services/heatmap_service.dart';
import '../app_theme.dart';
import '../shared/app_surface_card.dart';

class HeatmapEntryPanel extends StatelessWidget {
  const HeatmapEntryPanel({
    super.key,
    required this.summary,
    required this.onOpen,
    required this.onExport,
    required this.onImport,
  });

  final HeatmapSummary summary;
  final VoidCallback onOpen;
  final VoidCallback onExport;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      child: Row(
        children: [
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
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '当前连续 ${summary.currentStreak} 天 · 最长连续 ${summary.longestStreak} 天',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: textSecondaryColor, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: appSpace2),
          IconButton(
            key: const ValueKey('export-data-button'),
            tooltip: '导出备份',
            onPressed: onExport,
            color: accentColor,
            icon: const Icon(Icons.download),
          ),
          IconButton(
            key: const ValueKey('import-backup-button'),
            tooltip: '导入备份',
            onPressed: onImport,
            color: accentColor,
            icon: const Icon(Icons.upload_file),
          ),
          FilledButton.tonalIcon(
            key: const ValueKey('heatmap-entry-button'),
            onPressed: onOpen,
            icon: const Icon(Icons.grid_view, size: 18),
            label: const Text('打开'),
          ),
        ],
      ),
    );
  }
}
