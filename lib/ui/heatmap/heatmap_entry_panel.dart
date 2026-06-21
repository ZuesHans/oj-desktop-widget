import 'package:flutter/material.dart';

import '../../services/heatmap_service.dart';
import '../app_theme.dart';

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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_view_week, color: accentColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '热力图',
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Current ${summary.currentStreak}d · Longest ${summary.longestStreak}d',
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: textSecondaryColor, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('export-data-button'),
            tooltip: 'Export Backup',
            onPressed: onExport,
            color: accentColor,
            icon: const Icon(Icons.download),
          ),
          IconButton(
            key: const ValueKey('import-backup-button'),
            tooltip: 'Import Backup',
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
