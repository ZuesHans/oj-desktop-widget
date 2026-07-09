import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tray_manager/tray_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/oj_catalog.dart';
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
import '../app_labels.dart';
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
import 'dashboard_navigation.dart';
import 'dashboard_overview_layout.dart';
import 'dashboard_settings_panel.dart';
import 'daily_panel.dart';
import 'feature_page_shell.dart';
import 'home_summary_panel.dart';
import 'home_summary_view_model.dart';
import 'oj_tile.dart';
import 'summary_panel.dart';
import 'window_header.dart';

export 'home_summary_view_model.dart';

class OjFloatHome extends StatefulWidget {
  const OjFloatHome({
    super.key,
    this.initialConfig,
    this.enablePlatformIntegration = true,
    this.autoInitializeController = true,
  });

  final AppConfig? initialConfig;
  final bool enablePlatformIntegration;
  final bool autoInitializeController;

  @override
  State<OjFloatHome> createState() => _OjFloatHomeState();
}

class _OjFloatHomeState extends State<OjFloatHome>
    with TrayListener, WindowListener {
  late final OjController _controller;
  bool _exiting = false;
  HomeDisplayMode _mode = HomeDisplayMode.compact;
  DashboardSection _dashboardSection = DashboardSection.summary;

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
    if (widget.initialConfig != null) {
      _controller.state = _controller.state.copyWith(
        config: widget.initialConfig,
      );
    }
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
    await _showAndFocus();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (TrayCommand.fromKey(menuItem.key)) {
      case TrayCommand.show:
        await _showAndFocus();
        break;
      case TrayCommand.hide:
        await windowManager.hide();
        break;
      case TrayCommand.toggleOnTop:
        final nextConfig = _controller.state.config.copyWith(
          alwaysOnTop: !_controller.state.config.alwaysOnTop,
        );
        await _controller.saveConfig(nextConfig);
        await _applyWindowPreferences(nextConfig);
        await _setupTrayMenu();
        break;
      case TrayCommand.refresh:
        await _controller.refresh();
        break;
      case TrayCommand.exit:
        await _exitPlatformApp();
        break;
      case null:
        break;
    }
  }

  @override
  void onWindowClose() async {
    if (_exiting) {
      return;
    }
    if (_controller.state.config.closeToTray) {
      unawaited(windowManager.hide());
      return;
    }
    unawaited(_exitPlatformApp());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Theme(
          data: buildAppTheme(),
          child: Builder(
            builder: _buildMode,
          ),
        );
      },
    );
  }

  Widget _buildMode(BuildContext context) {
    return switch (_mode) {
      HomeDisplayMode.compact => Scaffold(
          backgroundColor: Colors.transparent,
          body: CompactWidget(
            state: _controller.state,
            refreshing: _controller.refreshing,
            onRefresh: _controller.refreshing ? null : _controller.refresh,
            onOpenDashboard: _openFromCompact,
            onExit: _exitApp,
          ),
        ),
      HomeDisplayMode.largeFloat => _buildLargeFloat(context),
      HomeDisplayMode.dashboard => _buildDashboard(context),
      HomeDisplayMode.heatmap => _featurePage(
          context,
          HeatmapPage(
            summary: HeatmapSummary.fromSnapshots(
              _controller.state.snapshots,
            ),
            onBack: () => _setMode(HomeDisplayMode.largeFloat),
            onExport: () => _exportData(context),
            onImport: () => _importData(context),
          ),
        ),
      HomeDisplayMode.problems => _featurePage(
          context,
          ProblemsPage(
            problems: _controller.state.problems,
            onBack: () => _setMode(HomeDisplayMode.largeFloat),
            onParseLink: _controller.parseProblemLink,
            onSave: _controller.saveProblem,
            onDelete: _controller.deleteProblem,
            onOpenProblem: _openProblemUrl,
          ),
        ),
      HomeDisplayMode.refreshLogs => _featurePage(
          context,
          RefreshLogsPage(
            logs: _controller.state.refreshLogs,
            onBack: () => _setMode(HomeDisplayMode.largeFloat),
          ),
        ),
      HomeDisplayMode.contests => _featurePage(
          context,
          ContestsPage(
            contests: _controller.state.contests,
            rankPoints: _controller.contestRankPoints(),
            onBack: () => _setMode(HomeDisplayMode.largeFloat),
            onSave: _controller.saveContest,
            onDelete: _controller.deleteContest,
          ),
        ),
      HomeDisplayMode.teammates => _featurePage(
          context,
          TeammatesPage(
            data: _controller.state.teammates,
            todayRanking: _controller.teammateTodayRanking(),
            recentRankings: _controller.teammateRecentRankings(),
            refreshing: _controller.refreshingTeammates,
            onBack: () => _setMode(HomeDisplayMode.largeFloat),
            onSave: _controller.saveTeammate,
            onDelete: _controller.deleteTeammate,
            onRefreshAll: _controller.refreshAllTeammates,
            onRefreshOne: _controller.refreshTeammate,
          ),
        ),
    };
  }

  Widget _featurePage(BuildContext context, Widget child) {
    return FeaturePageShell(
      header: _windowHeader(context),
      child: child,
    );
  }

  Widget _buildLargeFloat(BuildContext context) {
    return Scaffold(
      backgroundColor: appSurfaceColor,
      body: SafeArea(
        child: Column(
          children: [
            _windowHeader(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('open-dashboard-button'),
                  onPressed: () => _setMode(HomeDisplayMode.dashboard),
                  icon: const Icon(Icons.dashboard_customize_outlined),
                  label: const Text('进入 Dashboard'),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                key: const ValueKey('large-float-modules'),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: _dashboardModuleWidgets(context, largeFloatModules),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _windowHeader(
    BuildContext context, {
    VoidCallback? onSettings,
  }) {
    return WindowHeader(
      refreshing: _controller.refreshing,
      onRefresh: _controller.refreshing ? null : _controller.refresh,
      onSettings: onSettings ?? () => _openSettings(context),
      onCompact: () => _setMode(HomeDisplayMode.compact),
      onMinimize: () => unawaited(windowManager.minimize()),
      onExit: _exitApp,
      onStartDrag: () => unawaited(windowManager.startDragging()),
    );
  }

  void _exitApp() {
    unawaited(_exitPlatformApp());
  }

  Widget _buildDashboard(BuildContext context) {
    return DashboardShell(
      header: _windowHeader(
        context,
        onSettings: () {
          setState(() => _dashboardSection = DashboardSection.settings);
        },
      ),
      currentSection: _dashboardSection,
      onSectionSelected: (section) {
        setState(() => _dashboardSection = section);
      },
      child: _dashboardContent(context),
    );
  }

  Widget _dashboardContent(BuildContext context) {
    return switch (_dashboardSection) {
      DashboardSection.summary => ListView(
          key: const ValueKey('dashboard-section-summary'),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          children: _dashboardSummaryWidgets(context),
        ),
      DashboardSection.heatmap => HeatmapPage(
          summary: HeatmapSummary.fromSnapshots(_controller.state.snapshots),
          onBack: () {},
          onExport: () => _exportData(context),
          onImport: () => _importData(context),
          showBackButton: false,
        ),
      DashboardSection.problems => ProblemsPage(
          problems: _controller.state.problems,
          onBack: () {},
          onParseLink: _controller.parseProblemLink,
          onSave: _controller.saveProblem,
          onDelete: _controller.deleteProblem,
          onOpenProblem: _openProblemUrl,
          showBackButton: false,
        ),
      DashboardSection.refreshLogs => RefreshLogsPage(
          logs: _controller.state.refreshLogs,
          onBack: () {},
          showBackButton: false,
        ),
      DashboardSection.contests => ContestsPage(
          contests: _controller.state.contests,
          rankPoints: _controller.contestRankPoints(),
          onBack: () {},
          onSave: _controller.saveContest,
          onDelete: _controller.deleteContest,
          showBackButton: false,
        ),
      DashboardSection.teammates => TeammatesPage(
          data: _controller.state.teammates,
          todayRanking: _controller.teammateTodayRanking(),
          recentRankings: _controller.teammateRecentRankings(),
          refreshing: _controller.refreshingTeammates,
          onBack: () {},
          onSave: _controller.saveTeammate,
          onDelete: _controller.deleteTeammate,
          onRefreshAll: _controller.refreshAllTeammates,
          onRefreshOne: _controller.refreshTeammate,
          showBackButton: false,
        ),
      DashboardSection.ojAccounts => ListView(
          key: const ValueKey('dashboard-section-oj-accounts'),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          children: [
            const DashboardSectionTitle(section: DashboardSection.ojAccounts),
            const SizedBox(height: 10),
            ...supportedOjs.map(
              (meta) => OjTile(
                meta: meta,
                config: _controller.state.config.accounts[meta.id],
                results: _controller.state.latest[meta.id] ?? const [],
                today: _controller.todayDeltaFor(meta.id),
                accountToday: _controller.todayDeltaByAccountFor(meta.id),
              ),
            ),
          ],
        ),
      DashboardSection.daily => ListView(
          key: const ValueKey('dashboard-section-daily'),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          children: [
            const DashboardSectionTitle(section: DashboardSection.daily),
            const SizedBox(height: 10),
            DailyPanel(state: _controller.state),
          ],
        ),
      DashboardSection.settings => _buildDashboardSettings(context),
    };
  }

  List<Widget> _dashboardSummaryWidgets(BuildContext context) {
    final viewModel = HomeSummaryViewModel.fromState(
      _controller.state,
      refreshing: _controller.refreshing,
      syncing: _controller.syncing,
      lastSyncResult: _controller.lastSyncResult,
    );
    return [
      const DashboardSectionTitle(
        section: DashboardSection.summary,
        subtitle: '先看今天是否有推进，再处理补题、刷新和同步问题。',
      ),
      const SizedBox(height: 10),
      DashboardOverviewLayout(
        primary: HomeSummaryPanel(
          viewModel: viewModel,
          onOpenSettings: () {
            setState(() => _dashboardSection = DashboardSection.settings);
          },
          onRefresh: _controller.refreshing ? null : _controller.refresh,
          onOpenAction: _openHomeAction,
        ),
        aside: [
          HeatmapEntryPanel(
            summary: HeatmapSummary.fromSnapshots(_controller.state.snapshots),
            onOpen: () {
              setState(() => _dashboardSection = DashboardSection.heatmap);
            },
            onExport: () => _exportData(context),
            onImport: () => _importData(context),
          ),
          ProblemsEntryPanel(
            problems: _controller.state.problems,
            onOpen: () {
              setState(() => _dashboardSection = DashboardSection.problems);
            },
          ),
          RefreshLogsEntryPanel(
            logs: _controller.state.refreshLogs,
            onOpen: () {
              setState(() => _dashboardSection = DashboardSection.refreshLogs);
            },
          ),
        ],
        bottom: [
          ContestsEntryPanel(
            contests: _controller.state.contests,
            onOpen: () {
              setState(() => _dashboardSection = DashboardSection.contests);
            },
          ),
          TeammatesEntryPanel(
            teammates: _controller.state.teammates,
            todayRanking: _controller.teammateTodayRanking(),
            onOpen: () {
              setState(() => _dashboardSection = DashboardSection.teammates);
            },
          ),
          DailyPanel(state: _controller.state),
        ],
      ),
    ];
  }

  void _openHomeAction(HomeActionTarget target) {
    setState(() {
      _dashboardSection = switch (target) {
        HomeActionTarget.heatmap => DashboardSection.heatmap,
        HomeActionTarget.problems => DashboardSection.problems,
        HomeActionTarget.refreshLogs => DashboardSection.refreshLogs,
        HomeActionTarget.contests => DashboardSection.contests,
        HomeActionTarget.teammates => DashboardSection.teammates,
      };
    });
  }

  Widget _buildDashboardSettings(BuildContext context) {
    return DashboardSettingsPanel(
      config: _controller.state.config,
      onSaveConfig: (config) => _saveConfigFromDashboard(context, config),
      onOpenFullSettings: () => _openSettings(context),
    );
  }

  List<Widget> _dashboardModuleWidgets(
    BuildContext context,
    List<DashboardModule> modules,
  ) {
    return [
      for (final module in modules) ...[
        _dashboardModuleWidget(context, module),
        const SizedBox(height: 12),
      ],
    ];
  }

  Widget _dashboardModuleWidget(BuildContext context, DashboardModule module) {
    return switch (module) {
      DashboardModule.summary => SummaryPanel(state: _controller.state),
      DashboardModule.heatmap => HeatmapEntryPanel(
          summary: HeatmapSummary.fromSnapshots(
            _controller.state.snapshots,
          ),
          onOpen: _openHeatmap,
          onExport: () => _exportData(context),
          onImport: () => _importData(context),
        ),
      DashboardModule.problems => ProblemsEntryPanel(
          problems: _controller.state.problems,
          onOpen: () => _setMode(HomeDisplayMode.problems),
        ),
      DashboardModule.refreshLogs => RefreshLogsEntryPanel(
          logs: _controller.state.refreshLogs,
          onOpen: () => _setMode(HomeDisplayMode.refreshLogs),
        ),
      DashboardModule.contests => ContestsEntryPanel(
          contests: _controller.state.contests,
          onOpen: () => _setMode(HomeDisplayMode.contests),
        ),
      DashboardModule.teammates => TeammatesEntryPanel(
          teammates: _controller.state.teammates,
          todayRanking: _controller.teammateTodayRanking(),
          onOpen: () => _setMode(HomeDisplayMode.teammates),
        ),
      DashboardModule.ojAccounts => Column(
          children: [
            ...supportedOjs.map(
              (meta) => OjTile(
                meta: meta,
                config: _controller.state.config.accounts[meta.id],
                results: _controller.state.latest[meta.id] ?? const [],
                today: _controller.todayDeltaFor(meta.id),
                accountToday: _controller.todayDeltaByAccountFor(meta.id),
              ),
            ),
          ],
        ),
      DashboardModule.daily => DailyPanel(state: _controller.state),
    };
  }

  void _openHeatmap() {
    _setMode(HomeDisplayMode.heatmap);
  }

  void _openFromCompact() {
    _setMode(HomeDisplayMode.largeFloat);
  }

  Future<void> _saveConfigFromDashboard(
    BuildContext context,
    AppConfig config,
  ) async {
    try {
      await _controller.saveConfig(config);
      if (widget.enablePlatformIntegration) {
        await _applyWindowPreferences(config);
        await _setupTrayMenu();
      }
    } catch (error) {
      if (context.mounted) {
        _showFeedback(context, '${AppLabels.settingsSaveFailed}: $error');
      }
    }
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
      if (context.mounted) {
        _showFeedback(
          context,
          '${AppLabels.exportSuccessPrefix} ${result.directory.path}',
        );
      }
    } catch (error) {
      if (context.mounted) {
        _showFeedback(context, '${AppLabels.exportFailed}: $error');
      }
    }
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
      try {
        await _controller.saveSyncToken(result.syncToken);
        await _controller.saveConfig(result.config);
        if (widget.enablePlatformIntegration) {
          await _applyWindowPreferences(result.config);
          await _setupTrayMenu();
        }
        if (result.syncNow) {
          final syncResult = await _controller.syncNow();
          if (context.mounted) {
            _showFeedback(context, AppLabels.syncResultMessage(syncResult));
          }
        }
      } catch (error) {
        if (context.mounted) {
          _showFeedback(context, '${AppLabels.settingsSaveFailed}: $error');
        }
      }
    }
  }

  Future<void> _importData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(AppLabels.importBackup),
        content: const Text(AppLabels.importConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AppLabels.importBackup),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      final path = picked?.files.single.path;
      if (path == null) {
        return;
      }
      final result = await _controller.importPortableBackup(File(path));
      if (widget.enablePlatformIntegration) {
        await _applyWindowPreferences(_controller.state.config);
        await _setupTrayMenu();
      }
      if (context.mounted) {
        _showFeedback(
          context,
          '${AppLabels.importSuccessPrefix}${result.safetyBackupFile.path}',
        );
      }
    } catch (error) {
      if (context.mounted) {
        _showFeedback(context, '${AppLabels.importFailed}: $error');
      }
    }
  }

  Future<void> _openProblemUrl(ProblemRecord problem) async {
    final url = Uri.tryParse(problem.url);
    if (url == null || !await launchUrl(url)) {
      throw Exception(AppLabels.openProblemFailed);
    }
  }

  void _showFeedback(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _setMode(HomeDisplayMode mode) {
    if (_mode == mode) {
      return;
    }
    setState(() => _mode = mode);
    if (widget.enablePlatformIntegration) {
      unawaited(_syncWindowForMode(mode));
    }
  }

  Future<void> _setupTray() async {
    await trayManager.setIcon(
      Platform.isWindows ? 'assets/app_icon.ico' : 'assets/app_icon.png',
    );
    await trayManager.setToolTip(AppLabels.appTitle);
    await _setupTrayMenu();
  }

  Future<void> _setupTrayMenu() {
    return trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: TrayCommand.show.key, label: AppLabels.trayShowWindow),
          MenuItem(key: TrayCommand.hide.key, label: AppLabels.trayHideWindow),
          MenuItem.separator(),
          MenuItem(
            key: TrayCommand.toggleOnTop.key,
            label: AppLabels.trayToggleOnTop,
          ),
          MenuItem(
            key: TrayCommand.refresh.key,
            label: AppLabels.trayRefreshNow,
          ),
          MenuItem.separator(),
          MenuItem(key: TrayCommand.exit.key, label: AppLabels.trayExit),
        ],
      ),
    );
  }

  Future<void> _applyWindowPreferences(AppConfig config) async {
    await windowManager.setAlwaysOnTop(config.alwaysOnTop);
    await windowManager.setSkipTaskbar(!config.showInTaskbar);
  }

  Future<void> _syncWindowForMode(HomeDisplayMode mode) async {
    final (size, minimumSize) = switch (mode) {
      HomeDisplayMode.compact => (compactWindowSize, compactMinimumWindowSize),
      HomeDisplayMode.largeFloat => (
          largeFloatWindowSize,
          largeFloatMinimumWindowSize,
        ),
      HomeDisplayMode.dashboard => (
          dashboardWindowSize,
          dashboardMinimumWindowSize
        ),
      HomeDisplayMode.heatmap => (heatmapWindowSize, heatmapMinimumWindowSize),
      HomeDisplayMode.problems ||
      HomeDisplayMode.refreshLogs ||
      HomeDisplayMode.contests ||
      HomeDisplayMode.teammates =>
        (
          dashboardWindowSize,
          dashboardMinimumWindowSize,
        ),
    };
    await windowManager.setMinimumSize(minimumSize);
    await windowManager.setSize(size);
    await _showAndFocus();
  }

  Future<void> _showAndFocus() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _exitPlatformApp() async {
    _exiting = true;
    await trayManager.destroy();
    await windowManager.destroy();
  }
}
