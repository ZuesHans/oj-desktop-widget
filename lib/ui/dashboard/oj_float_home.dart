import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import '../../app/app_display_mode.dart';
import '../../core/errors.dart';
import '../../core/oj_catalog.dart';
import '../../core/solved_totals.dart';
import '../../models/app_config.dart';
import '../../models/problem_record.dart';
import '../../platform/startup_service.dart';
import '../../providers/atcoder_provider.dart';
import '../../providers/codeforces_provider.dart';
import '../../providers/leetcode_provider.dart';
import '../../providers/luogu_provider.dart';
import '../../providers/nowcoder_provider.dart';
import '../../services/backup_service.dart';
import '../../services/heatmap_service.dart';
import '../../services/local_store.dart';
import '../../services/oj_controller.dart';
import '../../services/refresh_service.dart';
import '../../services/sync_service.dart';
import '../app_theme.dart';
import '../compact/compact_widget.dart';
import '../contests/contests_entry_panel.dart';
import '../contests/contests_page.dart';
import '../heatmap/heatmap_entry_panel.dart';
import '../heatmap/heatmap_page.dart';
import '../problems/problems_entry_panel.dart';
import '../problems/problems_page.dart';
import '../refresh_logs/refresh_logs_entry_panel.dart';
import '../refresh_logs/refresh_logs_page.dart';
import '../settings/settings_dialog.dart';
import '../teammates/teammates_entry_panel.dart';
import '../teammates/teammates_page.dart';
import 'daily_panel.dart';
import 'oj_tile.dart';
import 'summary_panel.dart';
import 'window_header.dart';

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
            body: CompactWidget(
              state: _controller.state,
              refreshing: _controller.refreshing,
              onRefresh: _controller.refreshing ? null : _controller.refresh,
              onOpenDashboard: () => _setMode(AppDisplayMode.dashboard),
              onExit: _exitApp,
            ),
          );
        }

        if (_mode == AppDisplayMode.heatmap) {
          return Scaffold(
            backgroundColor: appSurfaceColor,
            body: SafeArea(
              child: Column(
                children: [
                  WindowHeader(
                    refreshing: _controller.refreshing,
                    onRefresh:
                        _controller.refreshing ? null : _controller.refresh,
                    onSettings: () => _openSettings(context),
                    onCompact: () => _setMode(AppDisplayMode.compact),
                    onMinimize: () => windowManager.minimize(),
                    onExit: _exitApp,
                  ),
                  Expanded(
                    child: HeatmapPage(
                      summary: HeatmapSummary.fromSnapshots(
                        _controller.state.snapshots,
                      ),
                      onBack: () => _setMode(AppDisplayMode.dashboard),
                      onExport: () => _exportData(context),
                      onImport: () => _importData(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (_mode == AppDisplayMode.problems) {
          return Scaffold(
            backgroundColor: appSurfaceColor,
            body: SafeArea(
              child: Column(
                children: [
                  WindowHeader(
                    refreshing: _controller.refreshing,
                    onRefresh:
                        _controller.refreshing ? null : _controller.refresh,
                    onSettings: () => _openSettings(context),
                    onCompact: () => _setMode(AppDisplayMode.compact),
                    onMinimize: () => windowManager.minimize(),
                    onExit: _exitApp,
                  ),
                  Expanded(
                    child: ProblemsPage(
                      problems: _controller.state.problems,
                      onBack: () => _setMode(AppDisplayMode.dashboard),
                      onParseLink: _controller.parseProblemLink,
                      onSave: _controller.saveProblem,
                      onDelete: _controller.deleteProblem,
                      onMarkAccepted: _controller.markProblemAccepted,
                      onOpenProblem: _openProblemUrl,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (_mode == AppDisplayMode.refreshLogs) {
          return Scaffold(
            backgroundColor: appSurfaceColor,
            body: SafeArea(
              child: Column(
                children: [
                  WindowHeader(
                    refreshing: _controller.refreshing,
                    onRefresh:
                        _controller.refreshing ? null : _controller.refresh,
                    onSettings: () => _openSettings(context),
                    onCompact: () => _setMode(AppDisplayMode.compact),
                    onMinimize: () => windowManager.minimize(),
                    onExit: _exitApp,
                  ),
                  Expanded(
                    child: RefreshLogsPage(
                      logs: _controller.state.refreshLogs,
                      onBack: () => _setMode(AppDisplayMode.dashboard),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (_mode == AppDisplayMode.contests) {
          return Scaffold(
            backgroundColor: appSurfaceColor,
            body: SafeArea(
              child: Column(
                children: [
                  WindowHeader(
                    refreshing: _controller.refreshing,
                    onRefresh:
                        _controller.refreshing ? null : _controller.refresh,
                    onSettings: () => _openSettings(context),
                    onCompact: () => _setMode(AppDisplayMode.compact),
                    onMinimize: () => windowManager.minimize(),
                    onExit: _exitApp,
                  ),
                  Expanded(
                    child: ContestsPage(
                      contests: _controller.state.contests,
                      rankPoints: _controller.contestRankPoints(),
                      onBack: () => _setMode(AppDisplayMode.dashboard),
                      onSave: _controller.saveContest,
                      onDelete: _controller.deleteContest,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (_mode == AppDisplayMode.teammates) {
          return Scaffold(
            backgroundColor: appSurfaceColor,
            body: SafeArea(
              child: Column(
                children: [
                  WindowHeader(
                    refreshing: _controller.refreshing,
                    onRefresh:
                        _controller.refreshing ? null : _controller.refresh,
                    onSettings: () => _openSettings(context),
                    onCompact: () => _setMode(AppDisplayMode.compact),
                    onMinimize: () => windowManager.minimize(),
                    onExit: _exitApp,
                  ),
                  Expanded(
                    child: TeammatesPage(
                      data: _controller.state.teammates,
                      todayRanking: _controller.teammateTodayRanking(),
                      recentRankings: _controller.teammateRecentRankings(),
                      refreshing: _controller.refreshingTeammates,
                      onBack: () => _setMode(AppDisplayMode.dashboard),
                      onSave: _controller.saveTeammate,
                      onDelete: _controller.deleteTeammate,
                      onRefreshAll: _controller.refreshAllTeammates,
                      onRefreshOne: _controller.refreshTeammate,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: appSurfaceColor,
          body: SafeArea(
            child: Column(
              children: [
                WindowHeader(
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
                      SummaryPanel(state: _controller.state),
                      const SizedBox(height: 12),
                      HeatmapEntryPanel(
                        summary: HeatmapSummary.fromSnapshots(
                          _controller.state.snapshots,
                        ),
                        onOpen: _openHeatmap,
                        onExport: () => _exportData(context),
                        onImport: () => _importData(context),
                      ),
                      const SizedBox(height: 12),
                      ProblemsEntryPanel(
                        problems: _controller.state.problems,
                        onOpen: () => _setMode(AppDisplayMode.problems),
                      ),
                      const SizedBox(height: 12),
                      RefreshLogsEntryPanel(
                        logs: _controller.state.refreshLogs,
                        onOpen: () => _setMode(AppDisplayMode.refreshLogs),
                      ),
                      const SizedBox(height: 12),
                      ContestsEntryPanel(
                        contests: _controller.state.contests,
                        onOpen: () => _setMode(AppDisplayMode.contests),
                      ),
                      const SizedBox(height: 12),
                      TeammatesEntryPanel(
                        teammates: _controller.state.teammates,
                        todayRanking: _controller.teammateTodayRanking(),
                        onOpen: () => _setMode(AppDisplayMode.teammates),
                      ),
                      const SizedBox(height: 12),
                      ...supportedOjs.map(
                        (meta) => OjTile(
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
                      DailyPanel(state: _controller.state),
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
    final syncToken = await _controller.loadSyncToken();
    if (!context.mounted) {
      return;
    }
    final result = await showDialog<SettingsDialogResult>(
      context: context,
      builder: (_) => SettingsDialog(
        config: _controller.state.config,
        initialSyncToken: syncToken,
      ),
    );
    if (result != null) {
      Object? saveError;
      try {
        await _controller.saveSyncToken(result.syncToken);
        await _controller.saveConfig(
          result.config,
          syncAfterRefresh: !result.syncNow,
        );
      } catch (error) {
        saveError = error;
      }
      if (widget.enablePlatformIntegration) {
        await _applyWindowPreferences(result.config);
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
      if (result.syncNow && saveError == null) {
        final syncResult = await _controller.syncNow();
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_formatSyncResult(syncResult))),
        );
      }
    }
  }

  String _formatSyncResult(SyncResult result) {
    switch (result.status) {
      case SyncStatus.success:
        return 'Sync succeeded: ${result.endpointLabel}';
      case SyncStatus.skipped:
        return 'Sync skipped: ${result.message}';
      case SyncStatus.failure:
        final target =
            result.endpointLabel.isEmpty ? 'endpoint' : result.endpointLabel;
        return 'Sync failed for $target: ${result.message}';
    }
  }

  void _openHeatmap() {
    _setMode(AppDisplayMode.heatmap);
  }

  Future<void> _exportData(BuildContext context) async {
    try {
      final result = await exportOjData(
        config: _controller.state.config,
        snapshots: _controller.state.snapshots,
        problems: _controller.state.problems,
        contests: _controller.state.contests,
        teammates: _controller.state.teammates,
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
          'Import will replace current local config, snapshots, problem book, '
          'contest records, and teammate data. Refresh logs are local-only '
          'diagnostics and will be cleared after import. A safety backup will '
          'be created before import.',
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
            'Import completed. Local config, snapshots, problem book, '
            'contest records, and teammate data were replaced from backup. '
            'Refresh logs were cleared because they are not part of portable '
            'backups. '
            'Safety backup: ${result.safetyBackupFile.path}',
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

  Future<void> _openProblemUrl(ProblemRecord problem) async {
    final uri = Uri.tryParse(problem.url);
    if (uri == null || !uri.hasScheme) {
      throw FetchException('Invalid problem URL.');
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      throw FetchException('Failed to open problem URL.');
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
          await windowManager.setResizable(false);
          await windowManager.setMinimumSize(compactMinimumWindowSize);
          await windowManager.setSize(compactWindowSize, animate: true);
          break;
        case AppDisplayMode.dashboard:
          await windowManager.setResizable(true);
          await windowManager.setMinimumSize(dashboardMinimumWindowSize);
          await windowManager.setSize(dashboardWindowSize, animate: true);
          break;
        case AppDisplayMode.heatmap:
          await windowManager.setResizable(true);
          await windowManager.setMinimumSize(heatmapMinimumWindowSize);
          await windowManager.setSize(heatmapWindowSize, animate: true);
          break;
        case AppDisplayMode.problems:
        case AppDisplayMode.refreshLogs:
          await windowManager.setResizable(true);
          await windowManager.setMinimumSize(heatmapMinimumWindowSize);
          await windowManager.setSize(const Size(760, 620), animate: true);
          break;
        case AppDisplayMode.contests:
          await windowManager.setResizable(true);
          await windowManager.setMinimumSize(heatmapMinimumWindowSize);
          await windowManager.setSize(const Size(760, 620), animate: true);
          break;
        case AppDisplayMode.teammates:
          await windowManager.setResizable(true);
          await windowManager.setMinimumSize(heatmapMinimumWindowSize);
          await windowManager.setSize(const Size(760, 620), animate: true);
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
