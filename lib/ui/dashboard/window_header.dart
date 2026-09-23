import 'package:flutter/material.dart';

import '../app_theme.dart';

class WindowHeader extends StatelessWidget {
  const WindowHeader({
    super.key,
    required this.sectionLabel,
    required this.refreshing,
    required this.onRefresh,
    required this.onSettings,
    this.onQuickEntry,
    this.quickEntryHotkey = 'Ctrl+Shift+O',
  });

  final String sectionLabel;
  final bool refreshing;
  final VoidCallback? onRefresh;
  final VoidCallback onSettings;
  final VoidCallback? onQuickEntry;
  final String quickEntryHotkey;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('app-toolbar'),
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: Image.asset(
              'assets/app_icon.png',
              key: const ValueKey('app-brand-icon'),
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              excludeFromSemantics: true,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'OJ Float',
            style: TextStyle(
              color: textPrimaryColor,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 10),
          Container(width: 1, height: 20, color: borderColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              sectionLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: textSecondaryColor, fontSize: 13),
            ),
          ),
          IconButton(
              tooltip: '快速录入 ($quickEntryHotkey)',
              onPressed: onQuickEntry,
              icon: const Icon(Icons.add_link)),
          IconButton(
            key: const ValueKey('toolbar-refresh-button'),
            tooltip: '立即刷新',
            onPressed: onRefresh,
            icon: refreshing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          IconButton(
            key: const ValueKey('toolbar-settings-button'),
            tooltip: '设置',
            onPressed: onSettings,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
    );
  }
}
