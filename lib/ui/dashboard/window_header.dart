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
    this.onSearch,
    this.quickEntryHotkey = 'Ctrl+Shift+O',
  });

  final String sectionLabel;
  final bool refreshing;
  final VoidCallback? onRefresh;
  final VoidCallback onSettings;
  final VoidCallback? onQuickEntry;
  final VoidCallback? onSearch;
  final String quickEntryHotkey;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('app-toolbar'),
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: appSurfaceColor,
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
          const SizedBox(width: 11),
          Text(
            'OJ Float',
            style: TextStyle(
              color: textPrimaryColor,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 10),
          Container(width: 1, height: 20, color: borderColor),
          const SizedBox(width: 10),
          Expanded(
            child: Row(children: [
              Flexible(
                child: Text(sectionLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: textPrimaryColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Text('/ 今天',
                  style: TextStyle(color: textSecondaryColor, fontSize: 13)),
            ]),
          ),
          if (onSearch != null) ...[
            _ToolbarSearch(onTap: onSearch!),
            const SizedBox(width: 10),
          ],
          if (onQuickEntry != null)
            _ToolbarIconButton(
                tooltip: '快速录入 ($quickEntryHotkey)',
                onPressed: onQuickEntry,
                icon: const Icon(Icons.add_link)),
          _ToolbarIconButton(
            buttonKey: const ValueKey('toolbar-refresh-button'),
            tooltip: '立即刷新 (Ctrl+R)',
            onPressed: onRefresh,
            icon: refreshing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          _ToolbarIconButton(
            buttonKey: const ValueKey('toolbar-settings-button'),
            tooltip: '设置 (Ctrl+,)',
            onPressed: onSettings,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
    );
  }
}

class _ToolbarSearch extends StatelessWidget {
  const _ToolbarSearch({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: appSurfaceColor,
        borderRadius: BorderRadius.circular(appRadiusControl),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(appRadiusControl),
          child: Container(
            width: 220,
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(appRadiusControl),
            ),
            child: Row(children: [
              Icon(Icons.search, size: 16, color: textSecondaryColor),
              const SizedBox(width: 7),
              Text('查找题目  Ctrl + F',
                  style: TextStyle(color: textSecondaryColor, fontSize: 12)),
            ]),
          ),
        ),
      );
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    this.buttonKey,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final Key? buttonKey;
  final String tooltip;
  final VoidCallback? onPressed;
  final Widget icon;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 34,
        height: 34,
        child: IconButton(
          key: buttonKey,
          tooltip: tooltip,
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 34, height: 34),
          style: IconButton.styleFrom(
            side: BorderSide(color: borderColor),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(appRadiusControl)),
          ),
          icon: icon,
        ),
      );
}
