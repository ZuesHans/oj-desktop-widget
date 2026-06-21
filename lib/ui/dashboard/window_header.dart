part of '../../main.dart';

class _WindowHeader extends StatelessWidget {
  const _WindowHeader({
    required this.refreshing,
    required this.onRefresh,
    required this.onSettings,
    required this.onCompact,
    required this.onMinimize,
    required this.onExit,
  });

  final bool refreshing;
  final VoidCallback? onRefresh;
  final VoidCallback onSettings;
  final VoidCallback onCompact;
  final VoidCallback onMinimize;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: Theme.of(context).colorScheme.surface,
        child: Row(
          children: [
            const Icon(Icons.bubble_chart_outlined),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'OJ Float',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ),
            IconButton(
              tooltip: '刷新',
              onPressed: onRefresh,
              icon: refreshing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: '设置',
              onPressed: onSettings,
              icon: const Icon(Icons.tune),
            ),
            IconButton(
              key: const ValueKey('compact-mode-button'),
              tooltip: 'Compact',
              onPressed: onCompact,
              icon: const Icon(Icons.close_fullscreen),
            ),
            IconButton(
              tooltip: '最小化',
              onPressed: onMinimize,
              icon: const Icon(Icons.remove),
            ),
            IconButton(
              key: const ValueKey('dashboard-exit-button'),
              tooltip: '退出程序',
              onPressed: onExit,
              icon: const Icon(Icons.power_settings_new),
            ),
          ],
        ),
      ),
    );
  }
}
