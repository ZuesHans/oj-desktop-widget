import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

const supportedOjs = <OjMeta>[
  OjMeta(
    id: 'codeforces',
    name: 'Codeforces',
    hint: 'handle',
    profileBaseUrl: 'https://codeforces.com/profile/',
  ),
  OjMeta(
    id: 'leetcode',
    name: 'LeetCode',
    hint: 'username',
    profileBaseUrl: 'https://leetcode.com/',
  ),
  OjMeta(
    id: 'atcoder',
    name: 'AtCoder',
    hint: 'username',
    profileBaseUrl: 'https://atcoder.jp/users/',
  ),
  OjMeta(
    id: 'luogu',
    name: '洛谷',
    hint: '数字 UID',
    profileBaseUrl: 'https://www.luogu.com.cn/user/',
  ),
  OjMeta(
    id: 'nowcoder',
    name: '牛客',
    hint: '数字用户 ID',
    profileBaseUrl: 'https://www.nowcoder.com/users/',
  ),
];

const _compactWindowSize = Size(220, 148);
const _compactMinimumWindowSize = Size(200, 132);
const _dashboardWindowSize = Size(360, 520);
const _dashboardMinimumWindowSize = Size(320, 420);
const _appSurfaceColor = Color(0xFFF6F7F4);
const _cardColor = Color(0xFFFFFFFF);
const _cardMutedColor = Color(0xFFF4F6F3);
const _borderColor = Color(0xFFE1E4DE);
const _textPrimaryColor = Color(0xFF17211D);
const _textSecondaryColor = Color(0xFF64706A);
const _accentColor = Color(0xFF2F6F4E);
const _dangerColor = Color(0xFFB3261E);
const _heatmapLevelColors = <Color>[
  Color(0xFFEFF3EF),
  Color(0xFF9BE9A8),
  Color(0xFF40C463),
  Color(0xFF30A14E),
  Color(0xFF216E39),
];

enum AppDisplayMode { compact, dashboard }

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    final initialConfig = await LocalStore().loadConfig();
    final options = WindowOptions(
      size: _compactWindowSize,
      minimumSize: _compactMinimumWindowSize,
      center: true,
      title: 'OJ Float',
      titleBarStyle: TitleBarStyle.hidden,
      alwaysOnTop: initialConfig.alwaysOnTop,
      backgroundColor: Colors.transparent,
      skipTaskbar: !initialConfig.showInTaskbar,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setPreventClose(true);
      await windowManager.show();
      await windowManager.focus();
    });
  }

  runApp(const OjFloatApp());
}

class OjFloatApp extends StatelessWidget {
  const OjFloatApp({
    super.key,
    this.enablePlatformIntegration = true,
    this.autoInitializeController = true,
  });

  final bool enablePlatformIntegration;
  final bool autoInitializeController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OJ Float',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F7D6D),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: OjFloatHome(
        enablePlatformIntegration: enablePlatformIntegration,
        autoInitializeController: autoInitializeController,
      ),
    );
  }
}

class OjFloatHome extends StatefulWidget {
  const OjFloatHome({
    super.key,
    this.enablePlatformIntegration = true,
    this.autoInitializeController = true,
  });

  final bool enablePlatformIntegration;
  final bool autoInitializeController;

  @override
  State<OjFloatHome> createState() => _OjFloatHomeState();
}

class _OjFloatHomeState extends State<OjFloatHome>
    with TrayListener, WindowListener {
  late final OjController _controller;
  AppDisplayMode _mode = AppDisplayMode.compact;

  @override
  void initState() {
    super.initState();
    _controller = OjController(
      storage: LocalStore(),
      startupService: widget.enablePlatformIntegration
          ? LaunchAtStartupService()
          : NoopStartupService(),
      service: RefreshService(
        client: http.Client(),
        providers: {
          'codeforces': CodeforcesProvider(),
          'leetcode': LeetCodeProvider(),
          'atcoder': AtCoderProvider(),
          'luogu': LuoguProvider(),
          'nowcoder': NowcoderProvider(),
        },
      ),
    );
    if (widget.enablePlatformIntegration) {
      trayManager.addListener(this);
      windowManager.addListener(this);
      unawaited(_setupTray());
    }
    if (widget.autoInitializeController) {
      unawaited(_controller.init().then((_) async {
        if (widget.enablePlatformIntegration) {
          await _applyWindowPreferences(_controller.state.config);
        }
      }));
    }
  }

  Future<void> _setupTray() async {
    if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return;
    }
    if (Platform.isWindows) {
      final iconFile = await _extractTrayIcon();
      await trayManager.setIcon(iconFile.path);
    }
    await trayManager.setToolTip('OJ Float');
    await _setupTrayMenu();
  }

  Future<void> _setupTrayMenu() async {
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: '显示窗口'),
          MenuItem(key: 'hide', label: '隐藏窗口'),
          MenuItem(key: 'toggle_on_top', label: '窗口置顶/取消置顶'),
          MenuItem.separator(),
          MenuItem(key: 'refresh', label: '立即刷新'),
          MenuItem.separator(),
          MenuItem(key: 'exit', label: '退出程序'),
        ],
      ),
    );
  }

  Future<File> _extractTrayIcon() async {
    final bytes = await rootBundle.load('assets/app_icon.ico');
    final directory = await getTemporaryDirectory();
    final iconFile =
        File('${directory.path}${Platform.pathSeparator}oj_float_app_icon.ico');
    await iconFile.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    return iconFile;
  }

  @override
  void dispose() {
    if (widget.enablePlatformIntegration) {
      trayManager.removeListener(this);
      windowManager.removeListener(this);
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  void onTrayIconMouseDown() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'show':
        await windowManager.show();
        await windowManager.focus();
        break;
      case 'hide':
        await windowManager.hide();
        break;
      case 'toggle_on_top':
        final nextConfig = _controller.state.config.copyWith(
          alwaysOnTop: !_controller.state.config.alwaysOnTop,
        );
        await _controller.saveConfig(nextConfig);
        await _applyWindowPreferences(nextConfig);
        await _setupTrayMenu();
        break;
      case 'refresh':
        await _controller.refresh();
        break;
      case 'exit':
        await _exitApp();
        break;
    }
  }

  @override
  void onWindowClose() async {
    if (_controller.state.config.closeToTray) {
      await windowManager.hide();
      return;
    }
    await _exitApp();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_mode == AppDisplayMode.compact) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: _CompactWidget(
              state: _controller.state,
              refreshing: _controller.refreshing,
              onRefresh: _controller.refreshing ? null : _controller.refresh,
              onOpenDashboard: () => _setMode(AppDisplayMode.dashboard),
              onExit: _exitApp,
            ),
          );
        }

        return Scaffold(
          backgroundColor: _appSurfaceColor,
          body: SafeArea(
            child: Column(
              children: [
                _WindowHeader(
                  refreshing: _controller.refreshing,
                  onRefresh:
                      _controller.refreshing ? null : _controller.refresh,
                  onSettings: () => _openSettings(context),
                  onCompact: () => _setMode(AppDisplayMode.compact),
                  onMinimize: () => windowManager.minimize(),
                  onExit: _exitApp,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                    children: [
                      _SummaryPanel(state: _controller.state),
                      const SizedBox(height: 12),
                      _HeatmapEntryPanel(
                        summary: HeatmapSummary.fromSnapshots(
                          _controller.state.snapshots,
                        ),
                        onOpen: () => _openHeatmap(context),
                        onExport: () => _exportData(context),
                        onImport: () => _importData(context),
                      ),
                      const SizedBox(height: 12),
                      ...supportedOjs.map(
                        (meta) => _OjTile(
                          meta: meta,
                          config: _controller.state.config.accounts[meta.id],
                          results:
                              _controller.state.latest[meta.id] ?? const [],
                          today: _controller.todayDeltaFor(meta.id),
                          accountToday:
                              _controller.todayDeltaByAccountFor(meta.id),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _DailyPanel(state: _controller.state),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSettings(BuildContext context) async {
    final updated = await showDialog<AppConfig>(
      context: context,
      builder: (_) => SettingsDialog(config: _controller.state.config),
    );
    if (updated != null) {
      Object? saveError;
      try {
        await _controller.saveConfig(updated);
      } catch (error) {
        saveError = error;
      }
      if (widget.enablePlatformIntegration) {
        await _applyWindowPreferences(updated);
        await _setupTrayMenu();
      }
      if (saveError != null) {
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Start at login update failed: ${normalizeError(saveError)}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _openHeatmap(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => HeatmapDialog(
        summary: HeatmapSummary.fromSnapshots(_controller.state.snapshots),
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    try {
      final result = await exportOjData(
        config: _controller.state.config,
        snapshots: _controller.state.snapshots,
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Exported portable backup JSON and daily summary CSV to ${result.directory.path}',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: ${normalizeError(error)}')),
      );
    }
  }

  Future<void> _importData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Import Backup'),
        content: const Text(
          'Import will replace current local config and snapshots. '
          'A safety backup will be created before import.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import Backup'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    try {
      final selection = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        allowMultiple: false,
      );
      final path = selection?.files.single.path;
      if (path == null) {
        return;
      }
      final result = await _controller.importPortableBackup(File(path));
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Import completed. Current config and snapshots were replaced '
            'from backup. Safety backup: ${result.safetyBackupFile.path}',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: ${normalizeError(error)}')),
      );
    }
  }

  void _setMode(AppDisplayMode mode) {
    if (_mode == mode) {
      return;
    }
    setState(() => _mode = mode);
    if (widget.enablePlatformIntegration) {
      unawaited(_syncWindowMode(mode));
    }
  }

  Future<void> _syncWindowMode(AppDisplayMode mode) async {
    try {
      switch (mode) {
        case AppDisplayMode.compact:
          await windowManager.setMinimumSize(_compactMinimumWindowSize);
          await windowManager.setSize(_compactWindowSize, animate: true);
          break;
        case AppDisplayMode.dashboard:
          await windowManager.setMinimumSize(_dashboardMinimumWindowSize);
          await windowManager.setSize(_dashboardWindowSize, animate: true);
          break;
      }
    } on MissingPluginException {
      // Widget tests do not load the desktop window plugin.
    }
  }

  Future<void> _applyWindowPreferences(AppConfig config) async {
    try {
      await windowManager.setAlwaysOnTop(config.alwaysOnTop);
      await windowManager.setSkipTaskbar(!config.showInTaskbar);
    } on MissingPluginException {
      // Widget tests do not load the desktop window plugin.
    }
  }

  Future<void> _exitApp() async {
    try {
      await windowManager.setPreventClose(false);
      await trayManager.destroy();
      await windowManager.destroy();
    } on MissingPluginException {
      // Widget tests do not load the desktop window or tray plugins.
    }
  }
}

class _CompactWidget extends StatelessWidget {
  const _CompactWidget({
    required this.state,
    required this.refreshing,
    required this.onRefresh,
    required this.onOpenDashboard,
    required this.onExit,
  });

  final OjState state;
  final bool refreshing;
  final VoidCallback? onRefresh;
  final VoidCallback onOpenDashboard;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final totalSolved = totalSolvedFromLatest(state.latest);
    final today = state.todaySummary.totalDelta;

    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        padding: const EdgeInsets.all(8),
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xEAF9FBF8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x66FFFFFF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CompactStatLine(
                        label: 'AC',
                        value: '$totalSolved',
                        isPrimary: true,
                      ),
                      const SizedBox(height: 6),
                      _CompactStatLine(
                        label: 'Today',
                        value: '+$today',
                        isPrimary: false,
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CompactIconButton(
                      key: const ValueKey('compact-refresh-button'),
                      tooltip: 'Refresh',
                      onPressed: onRefresh,
                      child: refreshing
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh, size: 18),
                    ),
                    const SizedBox(height: 4),
                    _CompactIconButton(
                      key: const ValueKey('open-dashboard-button'),
                      tooltip: 'Open dashboard',
                      onPressed: onOpenDashboard,
                      child: const Icon(Icons.open_in_full, size: 18),
                    ),
                    const SizedBox(height: 4),
                    _CompactIconButton(
                      key: const ValueKey('compact-exit-button'),
                      tooltip: '退出程序',
                      onPressed: onExit,
                      child: const Icon(Icons.power_settings_new, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactStatLine extends StatelessWidget {
  const _CompactStatLine({
    required this.label,
    required this.value,
    required this.isPrimary,
  });

  final String label;
  final String value;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 46,
          child: Text(
            label,
            style: TextStyle(
              color: const Color(0xFF42655C),
              fontSize: isPrimary ? 12 : 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF10231E),
              fontSize: isPrimary ? 30 : 18,
              fontWeight: isPrimary ? FontWeight.w900 : FontWeight.w800,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactIconButton extends StatelessWidget {
  const _CompactIconButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    required this.child,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 30,
        child: IconButton(
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          color: const Color(0xFF365F55),
          disabledColor: const Color(0x66365F55),
          onPressed: onPressed,
          icon: child,
        ),
      ),
    );
  }
}

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

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.state});

  final OjState state;

  @override
  Widget build(BuildContext context) {
    final totalSolved = totalSolvedFromLatest(state.latest);
    final today = state.todaySummary.totalDelta;
    final updatedAt = state.latest.values
        .expand((items) => items)
        .where((item) => item.fetchedAt != null)
        .map((item) => item.fetchedAt!)
        .fold<DateTime?>(null, (latest, item) {
      if (latest == null || item.isAfter(latest)) {
        return item;
      }
      return latest;
    });

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('总通过', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            '$totalSolved',
            style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w800),
          ),
          Row(
            children: [
              _Pill(label: '今日 +$today'),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  updatedAt == null ? '尚未刷新' : '更新 ${formatTime(updatedAt)}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _textSecondaryColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeatmapEntryPanel extends StatelessWidget {
  const _HeatmapEntryPanel({
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
        color: _cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_view_week, color: _accentColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Heatmap',
                  style: TextStyle(
                    color: _textPrimaryColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Current ${summary.currentStreak}d · Longest ${summary.longestStreak}d',
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: _textSecondaryColor, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('export-data-button'),
            tooltip: 'Export Backup',
            onPressed: onExport,
            color: _accentColor,
            icon: const Icon(Icons.download),
          ),
          IconButton(
            key: const ValueKey('import-backup-button'),
            tooltip: 'Import Backup',
            onPressed: onImport,
            color: _accentColor,
            icon: const Icon(Icons.upload_file),
          ),
          FilledButton.tonalIcon(
            key: const ValueKey('heatmap-entry-button'),
            onPressed: onOpen,
            icon: const Icon(Icons.grid_view, size: 18),
            label: const Text('Open'),
          ),
        ],
      ),
    );
  }
}

class HeatmapDialog extends StatelessWidget {
  const HeatmapDialog({super.key, required this.summary});

  final HeatmapSummary summary;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('heatmap-dialog'),
      backgroundColor: _cardColor,
      title: const Text(
        'Heatmap',
        style: TextStyle(color: _textPrimaryColor),
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _HeatmapStat(
                    label: 'Current streak',
                    value: '${summary.currentStreak}d'),
                _HeatmapStat(
                    label: 'Longest streak',
                    value: '${summary.longestStreak}d'),
                _HeatmapStat(
                    label: 'Active days', value: '${summary.activeDays}'),
                _HeatmapStat(label: 'Total +', value: '${summary.totalDelta}'),
              ],
            ),
            const SizedBox(height: 16),
            if (summary.days.isEmpty)
              const Text(
                'No snapshot data yet. Refresh after configuring accounts to build your heatmap.',
                style: TextStyle(color: _textSecondaryColor),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _heatmapWeeks(summary.days)
                      .map((week) => _HeatmapWeek(days: week))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _HeatmapStat extends StatelessWidget {
  const _HeatmapStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _cardMutedColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: _textSecondaryColor, fontSize: 11)),
          Text(
            value,
            style: const TextStyle(
              color: _textPrimaryColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeatmapWeek extends StatelessWidget {
  const _HeatmapWeek({required this.days});

  final List<HeatmapDay> days;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Column(
        children: days.map((day) => _HeatmapCell(day: day)).toList(),
      ),
    );
  }
}

class _HeatmapCell extends StatelessWidget {
  const _HeatmapCell({required this.day});

  final HeatmapDay day;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${day.date}: +${day.delta}',
      child: Container(
        width: 12,
        height: 12,
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: _heatmapColor(day.level),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

List<List<HeatmapDay>> _heatmapWeeks(List<HeatmapDay> days) {
  final weeks = <List<HeatmapDay>>[];
  for (var index = 0; index < days.length; index += 7) {
    final end = index + 7 > days.length ? days.length : index + 7;
    weeks.add(days.sublist(index, end));
  }
  return weeks;
}

Color _heatmapColor(int level) {
  return _heatmapLevelColors[level.clamp(0, _heatmapLevelColors.length - 1)];
}

class _OjTile extends StatelessWidget {
  const _OjTile({
    required this.meta,
    required this.config,
    required this.results,
    required this.today,
    required this.accountToday,
  });

  final OjMeta meta;
  final OjAccountConfig? config;
  final List<FetchResult> results;
  final int today;
  final Map<String, int> accountToday;

  @override
  Widget build(BuildContext context) {
    final enabled = config?.enabled ?? false;
    final usernames = config?.usernames ?? const <String>[];
    final hasSuccess =
        results.any((result) => result.status == FetchStatus.success);
    final successfulSolved = totalSolvedFromResults(results);
    final solvedText = hasSuccess
        ? '$successfulSolved'
        : results.any((result) => result.status == FetchStatus.failure)
            ? 'Failed'
            : enabled && usernames.isNotEmpty
                ? 'Pending'
                : 'Not set';
    final shownUsernames = {
      for (final result in results) result.username,
    };
    final pendingUsernames =
        usernames.where((username) => !shownUsernames.contains(username));
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: enabled
                ? Theme.of(context).colorScheme.primaryContainer
                : Colors.grey.shade200,
            child: Text(meta.name.characters.first),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(meta.name,
                    style: const TextStyle(
                      color: _textPrimaryColor,
                      fontWeight: FontWeight.w700,
                    )),
                Text(
                  usernames.isEmpty ? meta.hint : usernames.join(', '),
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: _textSecondaryColor, fontSize: 12),
                ),
                const SizedBox(height: 6),
                ...results.map(
                  (result) => _AccountResultLine(
                    result: result,
                    today: accountToday[result.username] ?? 0,
                  ),
                ),
                ...pendingUsernames.map(
                  (username) => _PendingAccountLine(username: username),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(solvedText,
                  style: const TextStyle(
                    color: _textPrimaryColor,
                    fontWeight: FontWeight.w800,
                  )),
              Text(
                '今日 +$today',
                style:
                    const TextStyle(color: _textSecondaryColor, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountResultLine extends StatelessWidget {
  const _AccountResultLine({required this.result, required this.today});

  final FetchResult result;
  final int today;

  @override
  Widget build(BuildContext context) {
    final statusText = switch (result.status) {
      FetchStatus.success => '${result.solvedCount ?? 0} (+$today)',
      FetchStatus.failure => 'Failed',
      FetchStatus.idle => 'Pending',
    };
    final color = result.status == FetchStatus.failure
        ? _dangerColor
        : _textSecondaryColor;

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  result.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: _textSecondaryColor, fontSize: 12),
                ),
              ),
              Text(
                statusText,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (result.error != null)
            Text(
              result.error!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _dangerColor, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _PendingAccountLine extends StatelessWidget {
  const _PendingAccountLine({required this.username});

  final String username;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _textSecondaryColor, fontSize: 12),
            ),
          ),
          const Text(
            'Pending',
            style: TextStyle(color: _textSecondaryColor, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

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

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _cardMutedColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _textPrimaryColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key, required this.config});

  final AppConfig config;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late int _intervalMinutes;
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, bool> _enabled;
  late bool _launchAtStartup;
  late bool _alwaysOnTop;
  late bool _showInTaskbar;
  late bool _closeToTray;

  @override
  void initState() {
    super.initState();
    _intervalMinutes = widget.config.refreshIntervalMinutes;
    _controllers = {
      for (final meta in supportedOjs)
        meta.id: TextEditingController(
          text: widget.config.accounts[meta.id]?.usernames.join(', ') ?? '',
        ),
    };
    _enabled = {
      for (final meta in supportedOjs)
        meta.id: widget.config.accounts[meta.id]?.enabled ?? false,
    };
    _launchAtStartup = widget.config.launchAtStartup;
    _alwaysOnTop = widget.config.alwaysOnTop;
    _showInTaskbar = widget.config.showInTaskbar;
    _closeToTray = widget.config.closeToTray;
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('设置'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('自动刷新间隔')),
                  SizedBox(
                    width: 110,
                    child: TextFormField(
                      initialValue: '$_intervalMinutes',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(suffixText: '分钟'),
                      onChanged: (value) {
                        _intervalMinutes = int.tryParse(value) ?? 60;
                      },
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                key: const ValueKey('launch-at-startup-switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Start at login'),
                value: _launchAtStartup,
                onChanged: (value) {
                  setState(() => _launchAtStartup = value);
                },
              ),
              SwitchListTile(
                key: const ValueKey('always-on-top-switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('窗口置顶'),
                value: _alwaysOnTop,
                onChanged: (value) {
                  setState(() => _alwaysOnTop = value);
                },
              ),
              SwitchListTile(
                key: const ValueKey('show-in-taskbar-switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('在任务栏显示'),
                value: _showInTaskbar,
                onChanged: (value) {
                  setState(() => _showInTaskbar = value);
                },
              ),
              SwitchListTile(
                key: const ValueKey('close-to-tray-switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('关闭时最小化到托盘'),
                value: _closeToTray,
                onChanged: (value) {
                  setState(() => _closeToTray = value);
                },
              ),
              const SizedBox(height: 10),
              ...supportedOjs.map((meta) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _enabled[meta.id] ?? false,
                        onChanged: (value) {
                          setState(() => _enabled[meta.id] = value ?? false);
                        },
                      ),
                      SizedBox(width: 88, child: Text(meta.name)),
                      Expanded(
                        child: TextField(
                          controller: _controllers[meta.id],
                          decoration: InputDecoration(
                            hintText: meta.hint,
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final accounts = {
              for (final meta in supportedOjs)
                meta.id: OjAccountConfig(
                  usernames: OjAccountConfig.normalizeUsernames(
                    [_controllers[meta.id]!.text],
                  ),
                  enabled: _enabled[meta.id] ?? false,
                ),
            };
            Navigator.pop(
              context,
              AppConfig(
                refreshIntervalMinutes:
                    _intervalMinutes.clamp(15, 1440).toInt(),
                accounts: accounts,
                launchAtStartup: _launchAtStartup,
                alwaysOnTop: _alwaysOnTop,
                showInTaskbar: _showInTaskbar,
                closeToTray: _closeToTray,
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class OjController extends ChangeNotifier {
  OjController({
    required this.storage,
    required this.service,
    required this.startupService,
  });

  final LocalStore storage;
  final RefreshService service;
  final StartupService startupService;
  OjState state = OjState.initial();
  bool refreshing = false;
  Timer? _timer;

  Future<void> init() async {
    final config = await storage.loadConfig();
    final snapshots = await storage.loadSnapshots();
    state = state.copyWith(config: config, snapshots: snapshots);
    _recomputeSummaries();
    _schedule();
    notifyListeners();
    await refresh();
  }

  Future<void> saveConfig(AppConfig config) async {
    await storage.saveConfig(config);
    state = state.copyWith(config: config);
    _schedule();
    notifyListeners();
    Object? startupError;
    try {
      final startupUpdated =
          await startupService.setEnabled(config.launchAtStartup);
      if (!startupUpdated) {
        startupError = FetchException('Start at login update failed.');
      }
    } catch (error) {
      startupError = error;
    }
    await refresh();
    if (startupError != null) {
      throw FetchException(normalizeError(startupError));
    }
  }

  Future<ImportResult> importPortableBackup(
    File backupFile, {
    Directory? safetyBackupDirectory,
  }) async {
    final imported = parsePortableBackupJson(await backupFile.readAsString());
    final previousConfig = state.config;
    final previousSnapshots = state.snapshots;
    final safetyBackup = await exportOjData(
      config: state.config,
      snapshots: state.snapshots,
      directory: safetyBackupDirectory,
      prefix: 'oj_float_pre_import_backup',
      writeDailySummary: false,
    );
    try {
      await storage.saveConfig(imported.config);
      await storage.replaceSnapshots(imported.snapshots);
    } catch (error) {
      try {
        await storage.saveConfig(previousConfig);
        await storage.replaceSnapshots(previousSnapshots);
      } catch (rollbackError) {
        throw FetchException(
          'Import failed and rollback failed: ${normalizeError(rollbackError)}',
        );
      }
      throw FetchException(
        'Import failed. Current config and snapshots were restored: '
        '${normalizeError(error)}',
      );
    }
    state = state.copyWith(
      config: await storage.loadConfig(),
      snapshots: await storage.loadSnapshots(),
      latest: const {},
    );
    _recomputeSummaries();
    _schedule();
    notifyListeners();
    try {
      final startupSynced =
          await startupService.setEnabled(state.config.launchAtStartup);
      if (!startupSynced) {
        throw FetchException('Start at login update failed.');
      }
    } catch (_) {
      // Import restores local state even if the OS startup toggle cannot sync.
    }
    return ImportResult(safetyBackupFile: safetyBackup.backupFile);
  }

  Future<void> refresh() async {
    if (refreshing) {
      return;
    }
    refreshing = true;
    notifyListeners();
    try {
      final results = await service.refresh(state.config);
      final snapshots = [
        ...state.snapshots,
        ...results.values
            .expand((items) => items)
            .map(SolvedSnapshot.fromResult),
      ];
      await storage.saveSnapshots(snapshots);
      state = state.copyWith(latest: results, snapshots: snapshots);
      _recomputeSummaries();
    } finally {
      refreshing = false;
      notifyListeners();
    }
  }

  int todayDeltaFor(String ojId) => state.todaySummary.deltas[ojId] ?? 0;

  Map<String, int> todayDeltaByAccountFor(String ojId) =>
      state.todaySummary.accountDeltas[ojId] ?? const {};

  void _recomputeSummaries() {
    final today = dateKey(DateTime.now());
    state = state.copyWith(
        todaySummary: DailySummary.fromSnapshots(today, state.snapshots));
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(minutes: state.config.refreshIntervalMinutes),
      (_) => unawaited(refresh()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    service.dispose();
    super.dispose();
  }
}

class RefreshService {
  RefreshService({required this.client, required this.providers});

  final http.Client client;
  final Map<String, OjProvider> providers;

  Future<Map<String, List<FetchResult>>> refresh(AppConfig config) async {
    final futures = <Future<MapEntry<String, FetchResult>>>[];
    for (final entry in config.accounts.entries) {
      if (!entry.value.enabled) {
        continue;
      }
      for (final username in entry.value.usernames) {
        futures.add(_refreshAccount(entry.key, username));
      }
    }
    final results = <String, List<FetchResult>>{};
    for (final entry in await Future.wait(futures)) {
      results.putIfAbsent(entry.key, () => []).add(entry.value);
    }
    return results;
  }

  Future<MapEntry<String, FetchResult>> _refreshAccount(
    String ojId,
    String username,
  ) async {
    final provider = providers[ojId]!;
    try {
      final profile = await provider
          .fetchProfile(client, username)
          .timeout(const Duration(seconds: 18));
      return MapEntry(
        ojId,
        FetchResult.success(
          ojId: ojId,
          username: username,
          solvedCount: profile.solvedCount,
          rating: profile.rating,
          profileUrl: profile.profileUrl,
          fetchedAt: DateTime.now(),
        ),
      );
    } catch (error) {
      return MapEntry(
        ojId,
        FetchResult.failure(
          ojId: ojId,
          username: username,
          error: normalizeError(error),
          fetchedAt: DateTime.now(),
        ),
      );
    }
  }

  void dispose() => client.close();
}

abstract class StartupService {
  Future<bool> setEnabled(bool enabled);
}

class NoopStartupService implements StartupService {
  @override
  Future<bool> setEnabled(bool enabled) async => true;
}

class LaunchAtStartupService implements StartupService {
  LaunchAtStartupService() {
    launchAtStartup.setup(
      appName: 'OJ Float',
      appPath: Platform.resolvedExecutable,
      packageName: 'oj_float',
    );
  }

  @override
  Future<bool> setEnabled(bool enabled) {
    return enabled ? launchAtStartup.enable() : launchAtStartup.disable();
  }
}

abstract class OjProvider {
  Future<OjProfile> fetchProfile(http.Client client, String username);
}

class CodeforcesProvider implements OjProvider {
  @override
  Future<OjProfile> fetchProfile(http.Client client, String username) async {
    final handle = normalizeCodeforcesHandle(username);
    final info = await readJson(
      client,
      Uri.https('codeforces.com', '/api/user.info', {'handles': handle}),
    );
    if (info['status'] != 'OK') {
      throw FetchException(info['comment']?.toString() ?? 'Codeforces 返回异常');
    }
    final result = info['result'];
    if (result is! List || result.isEmpty) {
      throw FetchException('Codeforces 用户不存在');
    }
    final user = result.first;
    final rating = user is Map && user['rating'] is num
        ? (user['rating'] as num).toInt()
        : null;

    final profileUrl = 'https://codeforces.com/profile/$handle';
    try {
      final response = await client
          .get(
            Uri.parse(profileUrl),
            headers: defaultHeaders(referer: 'https://codeforces.com/'),
          )
          .timeout(const Duration(seconds: 18));
      ensureOk(response);
      final solvedCount = parseCodeforcesProfileSolvedCount(response.body);
      if (solvedCount != null) {
        return OjProfile(
          solvedCount: solvedCount,
          profileUrl: profileUrl,
          rating: rating,
        );
      }
    } catch (_) {
      // Codeforces profile HTML can change; fall back to API submissions.
    }

    try {
      final solvedCount =
          await fetchCodeforcesSolvedCountFromSubmissions(client, handle);
      return OjProfile(
        solvedCount: solvedCount,
        profileUrl: profileUrl,
        rating: rating,
      );
    } catch (error) {
      throw FetchException(
        'Codeforces 主页数字解析失败，submission fallback 也失败：'
        '${normalizeError(error)}',
      );
    }
  }
}

String normalizeCodeforcesHandle(String input) {
  final value = input.trim();
  if (value.isEmpty) {
    throw FetchException('Codeforces 请填写 handle 或完整主页链接');
  }

  Uri? uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme) {
    uri = Uri.tryParse('https://$value');
  }

  if (uri != null &&
      uri.host.toLowerCase().replaceFirst('www.', '') == 'codeforces.com') {
    final segments = uri.pathSegments;
    if (segments.length >= 2 && segments.first == 'profile') {
      final handle = Uri.decodeComponent(segments[1]).trim();
      if (handle.isNotEmpty) {
        return handle;
      }
    }
    throw FetchException('Codeforces 请填写 handle 或完整主页链接');
  }

  if (value.contains('/') || value.contains('?') || value.contains('#')) {
    throw FetchException('Codeforces 请填写 handle 或完整主页链接');
  }
  return value;
}

int? parseCodeforcesProfileSolvedCount(String html) {
  final document = html_parser.parse(html);
  final bodyText = document.body?.text ?? document.documentElement?.text ?? '';
  final candidates = <String>[
    bodyText,
    html.replaceAll(RegExp(r'<[^>]+>'), ' '),
    html,
  ];
  final patterns = <RegExp>[
    RegExp(
      r'\bproblems?\s+solved\b[^\d]{0,120}([0-9][0-9,]*)',
      caseSensitive: false,
    ),
    RegExp(
      r'\bsolved\s+problems?\b[^\d]{0,120}([0-9][0-9,]*)',
      caseSensitive: false,
    ),
    RegExp(
      r'\bproblem\s+solved\b[^\d]{0,120}([0-9][0-9,]*)',
      caseSensitive: false,
    ),
  ];

  for (final candidate in candidates) {
    final normalized = candidate.replaceAll(RegExp(r'\s+'), ' ');
    for (final pattern in patterns) {
      final match = pattern.firstMatch(normalized);
      if (match != null) {
        return int.tryParse(match.group(1)!.replaceAll(',', ''));
      }
    }
  }
  return null;
}

String? codeforcesProblemKey(Map problem) {
  final contestId = problem['contestId'];
  final index = problem['index'];
  if (contestId != null && index != null) {
    return 'contest:$contestId/$index';
  }

  final problemsetName = problem['problemsetName'];
  if (problemsetName != null && index != null) {
    return 'problemset:$problemsetName/$index';
  }

  final name = problem['name'];
  if (name != null) {
    return 'name:$name';
  }

  return null;
}

int countCodeforcesSolvedSubmissions(List<dynamic> submissions) {
  final solved = <String>{};
  for (final item in submissions) {
    if (item is! Map || item['verdict'] != 'OK') {
      continue;
    }
    final problem = item['problem'];
    if (problem is Map) {
      final key = codeforcesProblemKey(problem);
      if (key != null) {
        solved.add(key);
      }
    }
  }
  return solved.length;
}

Future<int> fetchCodeforcesSolvedCountFromSubmissions(
  http.Client client,
  String handle,
) async {
  final data = await readJson(
    client,
    Uri.https('codeforces.com', '/api/user.status', {
      'handle': handle,
      'from': '1',
      'count': '100000',
    }),
  );
  if (data['status'] != 'OK') {
    throw FetchException(data['comment']?.toString() ?? 'Codeforces 返回异常');
  }
  final result = data['result'];
  if (result is! List) {
    throw FetchException('Codeforces 返回格式变化');
  }
  return countCodeforcesSolvedSubmissions(result);
}

class LeetCodeProvider implements OjProvider {
  @override
  Future<OjProfile> fetchProfile(http.Client client, String username) async {
    final response = await client
        .post(
          Uri.https('leetcode.com', '/graphql'),
          headers: defaultHeaders(
            referer: 'https://leetcode.com/$username/',
            contentType: 'application/json',
          ),
          body: jsonEncode({
            'query': '''
query userSessionProgress(\$username: String!) {
  matchedUser(username: \$username) {
    submitStatsGlobal {
      acSubmissionNum {
        difficulty
        count
      }
    }
  }
}
''',
            'variables': {'username': username},
          }),
        )
        .timeout(const Duration(seconds: 18));
    ensureOk(response);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final matchedUser = data['data']?['matchedUser'];
    if (matchedUser == null) {
      throw FetchException('LeetCode 用户不存在或不可公开访问');
    }
    final list = matchedUser['submitStatsGlobal']?['acSubmissionNum'];
    if (list is! List) {
      throw FetchException('LeetCode 返回格式变化');
    }
    final all = list.cast<Map<String, dynamic>>().firstWhere(
          (item) => item['difficulty'] == 'All',
          orElse: () => {'count': 0},
        );
    return OjProfile(
      solvedCount: all['count'] as int? ?? 0,
      profileUrl: 'https://leetcode.com/$username/',
    );
  }
}

class AtCoderProvider implements OjProvider {
  @override
  Future<OjProfile> fetchProfile(http.Client client, String username) async {
    final data = await readJson(
      client,
      Uri.https('kenkoooo.com', '/atcoder/atcoder-api/v3/user/ac_rank', {
        'user': username,
      }),
    );
    final count = data['count'];
    if (count is! int) {
      throw FetchException('AtCoder 统计接口未返回通过数');
    }
    return OjProfile(
      solvedCount: count,
      profileUrl: 'https://atcoder.jp/users/$username',
    );
  }
}

class LuoguProvider implements OjProvider {
  @override
  Future<OjProfile> fetchProfile(http.Client client, String username) async {
    if (int.tryParse(username) == null) {
      throw FetchException('洛谷第一版请填写数字 UID');
    }
    final uri = Uri.https('www.luogu.com.cn', '/user/$username');
    final response = await client.get(uri, headers: defaultHeaders()).timeout(
          const Duration(seconds: 18),
        );
    ensureOk(response);
    final body = response.body;
    final patterns = [
      RegExp(r'"passedProblemCount"\s*:\s*(\d+)'),
      RegExp(r'"acceptedProblemCount"\s*:\s*(\d+)'),
      RegExp(r'通过题目\s*</[^>]+>\s*<[^>]+>\s*(\d+)'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(body);
      if (match != null) {
        return OjProfile(
          solvedCount: int.parse(match.group(1)!),
          profileUrl: uri.toString(),
        );
      }
    }
    throw FetchException('洛谷页面未找到通过题数');
  }
}

class NowcoderProvider implements OjProvider {
  @override
  Future<OjProfile> fetchProfile(http.Client client, String username) async {
    final userId = normalizeNowcoderUserId(username);
    final uri = Uri.https('www.nowcoder.com', '/users/$userId');
    final response = await client.get(uri, headers: defaultHeaders()).timeout(
          const Duration(seconds: 18),
        );
    ensureOk(response);
    final body = response.body;
    return OjProfile(
      solvedCount: parseNowcoderSolvedCount(body),
      profileUrl: uri.toString(),
    );
  }
}

String normalizeNowcoderUserId(String value) {
  final input = value.trim();
  if (RegExp(r'^\d+$').hasMatch(input)) {
    return input;
  }
  final uri = Uri.tryParse(input);
  if (uri != null &&
      uri.host.toLowerCase().endsWith('nowcoder.com') &&
      uri.pathSegments.length >= 2 &&
      uri.pathSegments[0] == 'users' &&
      RegExp(r'^\d+$').hasMatch(uri.pathSegments[1])) {
    return uri.pathSegments[1];
  }
  throw FetchException(
      '牛客用户请输入数字用户 ID，或完整主页链接 https://www.nowcoder.com/users/数字ID');
}

int parseNowcoderSolvedCount(String body) {
  const jsonFields = [
    'acceptedCount',
    'acceptCount',
    'acCount',
    'solvedCount',
    'passedProblemCount',
  ];
  for (final field in jsonFields) {
    final match = RegExp('"$field"\\s*:\\s*(\\d+)').firstMatch(body);
    if (match != null) {
      return int.parse(match.group(1)!);
    }
  }

  final labelPattern = RegExp(r'(?:通过题目|已通过|AC题数)[^0-9]{0,80}(\d+)');
  final rawTextMatch = labelPattern.firstMatch(body);
  if (rawTextMatch != null) {
    return int.parse(rawTextMatch.group(1)!);
  }

  final document = html_parser.parse(body);
  final text = document.body?.text ?? '';
  final textMatch = labelPattern.firstMatch(text);
  if (textMatch != null) {
    return int.parse(textMatch.group(1)!);
  }
  throw FetchException('牛客页面未找到通过题目数，请确认主页可公开访问或页面结构未变更');
}

class LocalStore {
  LocalStore({Directory? supportDirectory})
      : _supportDirectory = supportDirectory;

  static const _configKey = 'app_config_v1';
  static const _snapshotsFile = 'snapshots_v1.json';

  final Directory? _supportDirectory;

  Future<AppConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_configKey);
    if (raw == null) {
      return AppConfig.defaults();
    }
    try {
      final data = jsonDecode(raw);
      if (data is! Map) {
        debugPrint('Invalid app config JSON: expected an object.');
        return AppConfig.defaults();
      }
      return AppConfig.fromJson(Map<String, dynamic>.from(data));
    } catch (_) {
      debugPrint('Failed to parse app config. Using defaults.');
      return AppConfig.defaults();
    }
  }

  Future<void> saveConfig(AppConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, jsonEncode(config.toJson()));
  }

  Future<List<SolvedSnapshot>> loadSnapshots() async {
    final file = await _snapshotFile();
    if (!await file.exists()) {
      return [];
    }
    try {
      final data = jsonDecode(await file.readAsString());
      if (data is! List) {
        debugPrint('Invalid snapshots JSON: expected a list.');
        return [];
      }
      final snapshots = <SolvedSnapshot>[];
      for (final item in data) {
        try {
          if (item is! Map) {
            debugPrint('Skipping invalid snapshot: expected an object.');
            continue;
          }
          final snapshot = SolvedSnapshot.tryFromJson(
            Map<String, dynamic>.from(item),
          );
          if (snapshot == null) {
            debugPrint('Skipping invalid snapshot entry.');
            continue;
          }
          snapshots.add(snapshot);
        } catch (_) {
          debugPrint('Skipping invalid snapshot entry.');
          continue;
        }
      }
      return snapshots;
    } catch (_) {
      debugPrint('Failed to parse snapshots. Using an empty list.');
      return [];
    }
  }

  Future<void> saveSnapshots(List<SolvedSnapshot> snapshots) async {
    final file = await _snapshotFile();
    await file.parent.create(recursive: true);
    final kept = snapshots.length > 6000
        ? snapshots.sublist(snapshots.length - 6000)
        : snapshots;
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        kept.map((item) => item.toJson()).toList(),
      ),
    );
  }

  Future<void> replaceSnapshots(List<SolvedSnapshot> snapshots) async {
    final file = await _snapshotFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        snapshots.map((item) => item.toJson()).toList(),
      ),
    );
  }

  Future<File> _snapshotFile() async {
    final directory =
        _supportDirectory ?? await getApplicationSupportDirectory();
    return File('${directory.path}${Platform.pathSeparator}$_snapshotsFile');
  }
}

class ExportResult {
  const ExportResult({
    required this.directory,
    required this.backupFile,
    required this.dailySummaryFile,
  });

  final Directory directory;
  final File backupFile;
  final File dailySummaryFile;
}

class ImportResult {
  const ImportResult({required this.safetyBackupFile});

  final File safetyBackupFile;
}

class ParsedPortableBackup {
  const ParsedPortableBackup({
    required this.config,
    required this.snapshots,
  });

  final AppConfig config;
  final List<SolvedSnapshot> snapshots;
}

Future<ExportResult> exportOjData({
  required AppConfig config,
  required List<SolvedSnapshot> snapshots,
  DateTime? now,
  Directory? directory,
  String prefix = 'oj_float_backup',
  bool writeDailySummary = true,
}) async {
  final exportTime = now ?? DateTime.now();
  final exportDirectory = directory ?? await exportDirectoryForOjData();
  await exportDirectory.create(recursive: true);

  final backupFile = File(
    '${exportDirectory.path}${Platform.pathSeparator}'
    '${buildExportFileName(prefix, 'json', exportTime)}',
  );
  final dailySummaryFile = File(
    '${exportDirectory.path}${Platform.pathSeparator}'
    '${buildExportFileName('oj_float_daily_summary', 'csv', exportTime)}',
  );

  await backupFile.writeAsString(
    buildPortableBackupJson(
      config: config,
      snapshots: snapshots,
      exportedAt: exportTime,
    ),
  );
  if (writeDailySummary) {
    await dailySummaryFile.writeAsString(buildDailySummaryCsv(snapshots));
  }

  return ExportResult(
    directory: exportDirectory,
    backupFile: backupFile,
    dailySummaryFile: dailySummaryFile,
  );
}

Future<Directory> exportDirectoryForOjData() async {
  try {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) {
      return downloads;
    }
  } on MissingPluginException {
    // Widget tests do not load the desktop path provider plugin.
  }
  final support = await getApplicationSupportDirectory();
  return Directory('${support.path}${Platform.pathSeparator}exports');
}

String buildPortableBackupJson({
  required AppConfig config,
  required List<SolvedSnapshot> snapshots,
  required DateTime exportedAt,
}) {
  return const JsonEncoder.withIndent('  ').convert(
    {
      'schemaVersion': 1,
      'app': 'oj_float',
      'exportType': 'portable_backup',
      'exportedAt': exportedAt.toIso8601String(),
      'config': buildPortableConfigJson(config),
      'snapshots': snapshots.map((snapshot) => snapshot.toJson()).toList(),
      'dailyStats': buildDailyStatsJson(snapshots),
    },
  );
}

ParsedPortableBackup parsePortableBackupJson(String jsonText) {
  final decoded = jsonDecode(jsonText);
  if (decoded is! Map) {
    throw const FormatException('Backup JSON must be an object.');
  }
  final data = Map<String, dynamic>.from(decoded);
  if (data['schemaVersion'] != 1) {
    throw const FormatException('Unsupported backup schemaVersion.');
  }
  if (data['app'] != 'oj_float') {
    throw const FormatException('Backup app does not match oj_float.');
  }
  if (data['exportType'] != 'portable_backup') {
    throw const FormatException('Backup exportType is not portable_backup.');
  }
  final rawConfig = data['config'];
  if (rawConfig is! Map) {
    throw const FormatException('Backup config is missing or invalid.');
  }
  final rawSnapshots = data['snapshots'];
  if (rawSnapshots is! List) {
    throw const FormatException('Backup snapshots must be an array.');
  }

  final snapshots = <SolvedSnapshot>[];
  for (final item in rawSnapshots) {
    try {
      if (item is! Map) {
        continue;
      }
      final snapshot = SolvedSnapshot.tryFromJson(
        Map<String, dynamic>.from(item),
      );
      if (snapshot != null) {
        snapshots.add(snapshot);
      }
    } catch (_) {
      continue;
    }
  }

  return ParsedPortableBackup(
    config: AppConfig.fromPortableJson(Map<String, dynamic>.from(rawConfig)),
    snapshots: List.unmodifiable(snapshots),
  );
}

Map<String, Object?> buildPortableConfigJson(AppConfig config) {
  return {
    'refreshIntervalMinutes': config.refreshIntervalMinutes,
    'launchAtStartup': config.launchAtStartup,
    'alwaysOnTop': config.alwaysOnTop,
    'showInTaskbar': config.showInTaskbar,
    'closeToTray': config.closeToTray,
    'accounts': [
      for (final meta in supportedOjs)
        {
          'ojId': meta.id,
          'enabled': config.accounts[meta.id]?.enabled ?? false,
          'usernames': config.accounts[meta.id]?.usernames ?? const <String>[],
        },
    ],
  };
}

List<Map<String, Object?>> buildDailyStatsJson(List<SolvedSnapshot> snapshots) {
  final dates = {
    for (final snapshot in snapshots)
      if (snapshot.status == FetchStatus.success) snapshot.date,
  }.toList()
    ..sort();
  return [
    for (final date in dates) _dailyStatJson(date, snapshots),
  ];
}

Map<String, Object?> _dailyStatJson(
  String date,
  List<SolvedSnapshot> snapshots,
) {
  final totalDelta = DailySummary.fromSnapshots(date, snapshots).totalDelta;
  return {
    'date': date,
    'totalDelta': totalDelta,
    'active': totalDelta > 0,
  };
}

String buildDailySummaryCsv(List<SolvedSnapshot> snapshots) {
  final buffer = StringBuffer('date,totalDelta,active\n');
  for (final stat in buildDailyStatsJson(snapshots)) {
    buffer.writeln('${stat['date']},${stat['totalDelta']},${stat['active']}');
  }
  return buffer.toString();
}

String buildExportFileName(String prefix, String extension, DateTime time) {
  final local = time.toLocal();
  final timestamp = '${local.year.toString().padLeft(4, '0')}'
      '${local.month.toString().padLeft(2, '0')}'
      '${local.day.toString().padLeft(2, '0')}_'
      '${local.hour.toString().padLeft(2, '0')}'
      '${local.minute.toString().padLeft(2, '0')}';
  return '${prefix}_$timestamp.$extension';
}

class OjMeta {
  const OjMeta({
    required this.id,
    required this.name,
    required this.hint,
    required this.profileBaseUrl,
  });

  final String id;
  final String name;
  final String hint;
  final String profileBaseUrl;
}

class AppConfig {
  const AppConfig({
    required this.refreshIntervalMinutes,
    required this.accounts,
    this.launchAtStartup = false,
    this.alwaysOnTop = true,
    this.showInTaskbar = true,
    this.closeToTray = true,
  });

  factory AppConfig.defaults() {
    return AppConfig(
      refreshIntervalMinutes: 60,
      launchAtStartup: false,
      alwaysOnTop: true,
      showInTaskbar: true,
      closeToTray: true,
      accounts: {
        for (final meta in supportedOjs)
          meta.id: const OjAccountConfig(usernames: [], enabled: false),
      },
    );
  }

  factory AppConfig.fromJson(Map<String, dynamic> json) {
    final rawAccounts = json['accounts'];
    return AppConfig(
      refreshIntervalMinutes: _parseRefreshInterval(
        json['refreshIntervalMinutes'],
      ),
      launchAtStartup: json['launchAtStartup'] is bool
          ? json['launchAtStartup'] as bool
          : false,
      alwaysOnTop:
          json['alwaysOnTop'] is bool ? json['alwaysOnTop'] as bool : true,
      showInTaskbar:
          json['showInTaskbar'] is bool ? json['showInTaskbar'] as bool : true,
      closeToTray:
          json['closeToTray'] is bool ? json['closeToTray'] as bool : true,
      accounts: {
        for (final meta in supportedOjs)
          meta.id: _parseAccountConfig(
            rawAccounts is Map ? rawAccounts[meta.id] : null,
          ),
      },
    );
  }

  factory AppConfig.fromPortableJson(Map<String, dynamic> json) {
    final rawAccounts = json['accounts'];
    if (rawAccounts is! List) {
      throw const FormatException('Backup config.accounts must be an array.');
    }
    final accounts = {
      for (final meta in supportedOjs)
        meta.id: const OjAccountConfig(usernames: [], enabled: false),
    };
    for (final item in rawAccounts) {
      if (item is! Map) {
        throw const FormatException('Backup account entry must be an object.');
      }
      final accountJson = Map<String, dynamic>.from(item);
      final ojId = accountJson['ojId'];
      if (ojId is! String || ojId.isEmpty) {
        throw const FormatException('Backup account ojId is invalid.');
      }
      if (!accounts.containsKey(ojId)) {
        continue;
      }
      accounts[ojId] = OjAccountConfig.fromJson(accountJson);
    }
    return AppConfig(
      refreshIntervalMinutes: _parseRefreshInterval(
        json['refreshIntervalMinutes'],
      ),
      launchAtStartup: json['launchAtStartup'] is bool
          ? json['launchAtStartup'] as bool
          : false,
      alwaysOnTop:
          json['alwaysOnTop'] is bool ? json['alwaysOnTop'] as bool : true,
      showInTaskbar:
          json['showInTaskbar'] is bool ? json['showInTaskbar'] as bool : true,
      closeToTray:
          json['closeToTray'] is bool ? json['closeToTray'] as bool : true,
      accounts: accounts,
    );
  }

  static int _parseRefreshInterval(Object? value) {
    if (value is! int || value < 15 || value > 1440) {
      return 60;
    }
    return value;
  }

  static OjAccountConfig _parseAccountConfig(Object? value) {
    if (value is! Map) {
      return const OjAccountConfig(usernames: [], enabled: false);
    }
    try {
      return OjAccountConfig.fromJson(Map<String, dynamic>.from(value));
    } catch (_) {
      debugPrint('Failed to parse OJ account config. Using defaults.');
      return const OjAccountConfig(usernames: [], enabled: false);
    }
  }

  final int refreshIntervalMinutes;
  final Map<String, OjAccountConfig> accounts;
  final bool launchAtStartup;
  final bool alwaysOnTop;
  final bool showInTaskbar;
  final bool closeToTray;

  AppConfig copyWith({
    int? refreshIntervalMinutes,
    Map<String, OjAccountConfig>? accounts,
    bool? launchAtStartup,
    bool? alwaysOnTop,
    bool? showInTaskbar,
    bool? closeToTray,
  }) {
    return AppConfig(
      refreshIntervalMinutes:
          refreshIntervalMinutes ?? this.refreshIntervalMinutes,
      accounts: accounts ?? this.accounts,
      launchAtStartup: launchAtStartup ?? this.launchAtStartup,
      alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
      showInTaskbar: showInTaskbar ?? this.showInTaskbar,
      closeToTray: closeToTray ?? this.closeToTray,
    );
  }

  Map<String, dynamic> toJson() => {
        'refreshIntervalMinutes': refreshIntervalMinutes,
        'launchAtStartup': launchAtStartup,
        'alwaysOnTop': alwaysOnTop,
        'showInTaskbar': showInTaskbar,
        'closeToTray': closeToTray,
        'accounts': {
          for (final entry in accounts.entries) entry.key: entry.value.toJson(),
        },
      };
}

class OjAccountConfig {
  const OjAccountConfig({required this.usernames, required this.enabled});

  factory OjAccountConfig.fromJson(Map<String, dynamic> json) {
    final rawUsernames =
        json.containsKey('usernames') ? json['usernames'] : json['username'];
    return OjAccountConfig(
      usernames: _parseUsernames(rawUsernames),
      enabled: json['enabled'] is bool ? json['enabled'] as bool : false,
    );
  }

  static List<String> normalizeUsernames(Iterable<Object?> values) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final value in values) {
      if (value is! String) {
        continue;
      }
      for (final item in value.split(',')) {
        final username = item.trim();
        if (username.isNotEmpty && seen.add(username)) {
          normalized.add(username);
        }
      }
    }
    return List.unmodifiable(normalized);
  }

  static List<String> _parseUsernames(Object? value) {
    if (value is List) {
      return normalizeUsernames(value);
    }
    if (value is String) {
      return normalizeUsernames([value]);
    }
    return const [];
  }

  final List<String> usernames;
  final bool enabled;

  Map<String, dynamic> toJson() => {
        'usernames': usernames,
        'enabled': enabled,
      };
}

class OjProfile {
  const OjProfile({
    required this.solvedCount,
    required this.profileUrl,
    this.rating,
  });

  final int solvedCount;
  final int? rating;
  final String profileUrl;
}

enum FetchStatus { idle, success, failure }

class FetchResult {
  const FetchResult({
    required this.ojId,
    required this.username,
    required this.status,
    required this.fetchedAt,
    this.solvedCount,
    this.rating,
    this.profileUrl,
    this.error,
  });

  factory FetchResult.success({
    required String ojId,
    required String username,
    required int solvedCount,
    required DateTime fetchedAt,
    int? rating,
    String? profileUrl,
  }) {
    return FetchResult(
      ojId: ojId,
      username: username,
      status: FetchStatus.success,
      solvedCount: solvedCount,
      rating: rating,
      profileUrl: profileUrl,
      fetchedAt: fetchedAt,
    );
  }

  factory FetchResult.failure({
    required String ojId,
    required String username,
    required String error,
    required DateTime fetchedAt,
  }) {
    return FetchResult(
      ojId: ojId,
      username: username,
      status: FetchStatus.failure,
      error: error,
      fetchedAt: fetchedAt,
    );
  }

  final String ojId;
  final String username;
  final FetchStatus status;
  final int? solvedCount;
  final int? rating;
  final String? profileUrl;
  final String? error;
  final DateTime? fetchedAt;
}

class SolvedSnapshot {
  const SolvedSnapshot({
    required this.date,
    required this.fetchedAt,
    required this.ojId,
    required this.username,
    required this.status,
    this.solvedCount,
    this.error,
  });

  factory SolvedSnapshot.fromResult(FetchResult result) {
    final fetchedAt = result.fetchedAt ?? DateTime.now();
    return SolvedSnapshot(
      date: dateKey(fetchedAt),
      fetchedAt: fetchedAt,
      ojId: result.ojId,
      username: result.username,
      status: result.status,
      solvedCount: result.solvedCount,
      error: result.error,
    );
  }

  factory SolvedSnapshot.fromJson(Map<String, dynamic> json) {
    final snapshot = SolvedSnapshot.tryFromJson(json);
    if (snapshot == null) {
      throw const FormatException('Invalid solved snapshot JSON.');
    }
    return snapshot;
  }

  static SolvedSnapshot? tryFromJson(Map<String, dynamic> json) {
    final date = json['date'];
    final fetchedAt = json['fetchedAt'];
    final ojId = json['ojId'];
    final username = json['username'];
    final status = json['status'];
    final solvedCount = json['solvedCount'];
    final error = json['error'];

    if (date is! String || !_isValidDateKey(date)) {
      return null;
    }
    if (fetchedAt is! String) {
      return null;
    }
    final parsedFetchedAt = DateTime.tryParse(fetchedAt);
    if (parsedFetchedAt == null) {
      return null;
    }
    if (ojId is! String || ojId.isEmpty) {
      return null;
    }
    if (status is! String) {
      return null;
    }
    final parsedStatus = _parseFetchStatus(status);
    if (parsedStatus == null) {
      return null;
    }
    if (username != null && username is! String) {
      return null;
    }
    if (solvedCount != null && solvedCount is! int) {
      return null;
    }
    if (error != null && error is! String) {
      return null;
    }

    return SolvedSnapshot(
      date: date,
      fetchedAt: parsedFetchedAt,
      ojId: ojId,
      username: username as String? ?? '',
      status: parsedStatus,
      solvedCount: solvedCount as int?,
      error: error as String?,
    );
  }

  static FetchStatus? _parseFetchStatus(String value) {
    for (final status in FetchStatus.values) {
      if (status.name == value) {
        return status;
      }
    }
    return null;
  }

  static bool _isValidDateKey(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) {
      return false;
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day;
  }

  final String date;
  final DateTime fetchedAt;
  final String ojId;
  final String username;
  final FetchStatus status;
  final int? solvedCount;
  final String? error;

  Map<String, dynamic> toJson() => {
        'date': date,
        'fetchedAt': fetchedAt.toIso8601String(),
        'ojId': ojId,
        'username': username,
        'status': status.name,
        'solvedCount': solvedCount,
        'error': error,
      };
}

class DailySummary {
  const DailySummary({
    required this.date,
    required this.deltas,
    required this.accountDeltas,
    required this.totalDelta,
  });

  factory DailySummary.empty(String date) {
    return DailySummary(
      date: date,
      deltas: const {},
      accountDeltas: const {},
      totalDelta: 0,
    );
  }

  factory DailySummary.fromSnapshots(
      String date, List<SolvedSnapshot> snapshots) {
    final byAccount = <String, List<SolvedSnapshot>>{};
    for (final snapshot in snapshots.where(
      (item) => item.date == date && item.status == FetchStatus.success,
    )) {
      byAccount
          .putIfAbsent('${snapshot.ojId}\u0000${snapshot.username}', () => [])
          .add(snapshot);
    }
    final deltas = <String, int>{};
    final accountDeltas = <String, Map<String, int>>{};
    for (final entry in byAccount.entries) {
      final ordered = [...entry.value]
        ..sort((a, b) => a.fetchedAt.compareTo(b.fetchedAt));
      final ojId = ordered.first.ojId;
      final username = ordered.first.username;
      final first = ordered.first.solvedCount ?? 0;
      final last = ordered.last.solvedCount ?? 0;
      final delta = (last - first).clamp(0, 1 << 31).toInt();
      accountDeltas.putIfAbsent(ojId, () => {})[username] = delta;
      deltas[ojId] = (deltas[ojId] ?? 0) + delta;
    }
    return DailySummary(
      date: date,
      deltas: deltas,
      accountDeltas: accountDeltas,
      totalDelta: deltas.values.fold(0, (sum, item) => sum + item),
    );
  }

  final String date;
  final Map<String, int> deltas;
  final Map<String, Map<String, int>> accountDeltas;
  final int totalDelta;
}

class HeatmapDay {
  const HeatmapDay({required this.date, required this.delta});

  final String date;
  final int delta;

  bool get active => delta > 0;

  int get level {
    if (delta <= 0) {
      return 0;
    }
    if (delta == 1) {
      return 1;
    }
    if (delta <= 3) {
      return 2;
    }
    if (delta <= 6) {
      return 3;
    }
    return 4;
  }
}

class HeatmapSummary {
  const HeatmapSummary({
    required this.days,
    required this.currentStreak,
    required this.longestStreak,
    required this.activeDays,
    required this.totalDelta,
  });

  factory HeatmapSummary.fromSnapshots(
    List<SolvedSnapshot> snapshots, {
    DateTime? today,
    int weeks = 26,
  }) {
    if (snapshots.isEmpty) {
      return const HeatmapSummary(
        days: [],
        currentStreak: 0,
        longestStreak: 0,
        activeDays: 0,
        totalDelta: 0,
      );
    }

    final normalizedToday = _startOfDay(today ?? DateTime.now());
    final deltasByDate = _dailyDeltasByDate(snapshots);
    final days = <HeatmapDay>[];
    final visibleDayCount = weeks * 7;
    final start = normalizedToday.subtract(Duration(days: visibleDayCount - 1));
    for (var offset = 0; offset < visibleDayCount; offset += 1) {
      final date = start.add(Duration(days: offset));
      final key = dateKey(date);
      days.add(HeatmapDay(date: key, delta: deltasByDate[key] ?? 0));
    }

    return HeatmapSummary(
      days: List.unmodifiable(days),
      currentStreak: _currentStreak(deltasByDate, normalizedToday),
      longestStreak: _longestStreak(deltasByDate),
      activeDays: days.where((day) => day.active).length,
      totalDelta: days.fold(0, (sum, day) => sum + day.delta),
    );
  }

  final List<HeatmapDay> days;
  final int currentStreak;
  final int longestStreak;
  final int activeDays;
  final int totalDelta;
}

Map<String, int> _dailyDeltasByDate(List<SolvedSnapshot> snapshots) {
  final dates = {
    for (final snapshot in snapshots) snapshot.date,
  }.toList()
    ..sort();
  return {
    for (final date in dates)
      date: DailySummary.fromSnapshots(date, snapshots).totalDelta,
  };
}

int _currentStreak(Map<String, int> deltasByDate, DateTime today) {
  var count = 0;
  var cursor = _startOfDay(today);
  while ((deltasByDate[dateKey(cursor)] ?? 0) > 0) {
    count += 1;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return count;
}

int _longestStreak(Map<String, int> deltasByDate) {
  if (deltasByDate.isEmpty) {
    return 0;
  }
  final dates = deltasByDate.keys.map(_dateFromKey).toList()..sort();
  var longest = 0;
  var current = 0;
  var cursor = dates.first;
  final end = dates.last;
  while (!cursor.isAfter(end)) {
    if ((deltasByDate[dateKey(cursor)] ?? 0) > 0) {
      current += 1;
      if (current > longest) {
        longest = current;
      }
    } else {
      current = 0;
    }
    cursor = cursor.add(const Duration(days: 1));
  }
  return longest;
}

DateTime _dateFromKey(String value) {
  return DateTime(
    int.parse(value.substring(0, 4)),
    int.parse(value.substring(5, 7)),
    int.parse(value.substring(8, 10)),
  );
}

DateTime _startOfDay(DateTime date) {
  final local = date.toLocal();
  return DateTime(local.year, local.month, local.day);
}

class OjState {
  const OjState({
    required this.config,
    required this.latest,
    required this.snapshots,
    required this.todaySummary,
  });

  factory OjState.initial() {
    final today = dateKey(DateTime.now());
    return OjState(
      config: AppConfig.defaults(),
      latest: const {},
      snapshots: const [],
      todaySummary: DailySummary.empty(today),
    );
  }

  final AppConfig config;
  final Map<String, List<FetchResult>> latest;
  final List<SolvedSnapshot> snapshots;
  final DailySummary todaySummary;

  OjState copyWith({
    AppConfig? config,
    Map<String, List<FetchResult>>? latest,
    List<SolvedSnapshot>? snapshots,
    DailySummary? todaySummary,
  }) {
    return OjState(
      config: config ?? this.config,
      latest: latest ?? this.latest,
      snapshots: snapshots ?? this.snapshots,
      todaySummary: todaySummary ?? this.todaySummary,
    );
  }
}

class FetchException implements Exception {
  FetchException(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<Map<String, dynamic>> readJson(http.Client client, Uri uri) async {
  final response = await client.get(uri, headers: defaultHeaders()).timeout(
        const Duration(seconds: 18),
      );
  ensureOk(response);
  return jsonDecode(response.body) as Map<String, dynamic>;
}

Map<String, String> defaultHeaders({String? referer, String? contentType}) {
  return {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/126.0 Safari/537.36',
    'Accept': 'application/json,text/html,application/xhtml+xml',
    if (referer != null) 'Referer': referer,
    if (contentType != null) 'Content-Type': contentType,
  };
}

void ensureOk(http.Response response) {
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw FetchException('HTTP ${response.statusCode}');
  }
}

int totalSolvedFromLatest(Map<String, List<FetchResult>> latest) {
  return latest.values.fold<int>(
    0,
    (sum, results) => sum + totalSolvedFromResults(results),
  );
}

int totalSolvedFromResults(Iterable<FetchResult> results) {
  return results
      .where((result) => result.status == FetchStatus.success)
      .fold<int>(0, (sum, result) => sum + (result.solvedCount ?? 0));
}

String normalizeError(Object error) {
  if (error is FetchException) {
    return error.message;
  }
  if (error is TimeoutException) {
    return '请求超时';
  }
  if (error is SocketException) {
    return '网络不可用';
  }
  return error.toString();
}

String dateKey(DateTime date) {
  final local = date.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

String formatTime(DateTime date) {
  final local = date.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
