import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../app/app_display_mode.dart';
import '../../core/oj_catalog.dart';
import '../../models/app_config.dart';
import '../../platform/startup_service.dart';
import '../../providers/atcoder_provider.dart';
import '../../providers/codeforces_provider.dart';
import '../../providers/leetcode_provider.dart';
import '../../providers/luogu_provider.dart';
import '../../providers/nowcoder_provider.dart';
import '../../services/home_action_service.dart';
import '../../services/heatmap_service.dart';
import '../../services/local_store.dart';
import '../../services/oj_controller.dart';
import '../../services/refresh_service.dart';
import '../../services/window_shell_service.dart';
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
import 'daily_panel.dart';
import 'home_summary_panel.dart';
import 'home_summary_view_model.dart';
import 'oj_tile.dart';
import 'summary_panel.dart';
import 'window_header.dart';

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
  late final WindowShellService _shell;
  late final HomeActionService _actions;
  AppDisplayMode _mode = AppDisplayMode.compact;
  _DashboardSection _dashboardSection = _DashboardSection.summary;

  @override
  void initState() {
    super.initState();
    _shell = WindowShellService();
    _actions = HomeActionService();
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
      unawaited(_shell.setupTray());
    }
    if (widget.autoInitializeController) {
      unawaited(_controller.init().then((_) async {
        if (widget.enablePlatformIntegration) {
          await _shell.applyPreferences(_controller.state.config);
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
    await _shell.showAndFocus();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (WindowShellTrayCommand.fromKey(menuItem.key)) {
      case WindowShellTrayCommand.show:
        await _shell.showAndFocus();
        break;
      case WindowShellTrayCommand.hide:
        await _shell.hide();
        break;
      case WindowShellTrayCommand.toggleOnTop:
        final nextConfig = _controller.state.config.copyWith(
          alwaysOnTop: !_controller.state.config.alwaysOnTop,
        );
        await _controller.saveConfig(nextConfig);
        await _shell.applyPreferences(nextConfig);
        await _shell.setupTrayMenu();
        break;
      case WindowShellTrayCommand.refresh:
        await _controller.refresh();
        break;
      case WindowShellTrayCommand.exit:
        await _shell.exitApp();
        break;
      case null:
        break;
    }
  }

  @override
  void onWindowClose() async {
    if (_controller.state.config.closeToTray) {
      await _shell.hide();
      return;
    }
    await _shell.exitApp();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Theme(
          data: buildAppTheme(_controller.state.config.colorTheme),
          child: Builder(
            builder: (context) {
              if (_mode == AppDisplayMode.compact) {
                return Scaffold(
                  backgroundColor: Colors.transparent,
                  body: CompactWidget(
                    state: _controller.state,
                    refreshing: _controller.refreshing,
                    onOpenDashboard: _openFromCompact,
                  ),
                );
              }

              if (_mode == AppDisplayMode.largeFloat) {
                return _buildLargeFloat(context);
              }

              if (_mode == AppDisplayMode.dashboard) {
                return _buildDashboard(context);
              }

              if (_mode == AppDisplayMode.heatmap) {
                return Scaffold(
                  backgroundColor: appSurfaceColor,
                  body: SafeArea(
                    child: Column(
                      children: [
                        _windowHeader(context),
                        Expanded(
                          child: HeatmapPage(
                            summary: HeatmapSummary.fromSnapshots(
                              _controller.state.snapshots,
                            ),
                            onBack: () => _setMode(AppDisplayMode.largeFloat),
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
                        _windowHeader(context),
                        Expanded(
                          child: ProblemsPage(
                            problems: _controller.state.problems,
                            onBack: () => _setMode(AppDisplayMode.largeFloat),
                            onParseLink: _controller.parseProblemLink,
                            onSave: _controller.saveProblem,
                            onDelete: _controller.deleteProblem,
                            onOpenProblem: _actions.openProblemUrl,
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
                        _windowHeader(context),
                        Expanded(
                          child: RefreshLogsPage(
                            logs: _controller.state.refreshLogs,
                            onBack: () => _setMode(AppDisplayMode.largeFloat),
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
                        _windowHeader(context),
                        Expanded(
                          child: ContestsPage(
                            contests: _controller.state.contests,
                            rankPoints: _controller.contestRankPoints(),
                            onBack: () => _setMode(AppDisplayMode.largeFloat),
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
                        _windowHeader(context),
                        Expanded(
                          child: TeammatesPage(
                            data: _controller.state.teammates,
                            todayRanking: _controller.teammateTodayRanking(),
                            recentRankings:
                                _controller.teammateRecentRankings(),
                            refreshing: _controller.refreshingTeammates,
                            onBack: () => _setMode(AppDisplayMode.largeFloat),
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

              return _buildLargeFloat(context);
            },
          ),
        );
      },
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
                  onPressed: () => _setMode(AppDisplayMode.dashboard),
                  icon: const Icon(Icons.dashboard_customize_outlined),
                  label: const Text('进入 Dashboard'),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                key: const ValueKey('large-float-modules'),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: _dashboardModuleWidgets(context),
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
      onCompact: () => _setMode(AppDisplayMode.compact),
      onMinimize: () => unawaited(_shell.minimize()),
      onExit: () => unawaited(_shell.exitApp()),
      onStartDrag: () => unawaited(_shell.startDragging()),
    );
  }

  Widget _buildDashboard(BuildContext context) {
    return Scaffold(
      key: const ValueKey('dashboard-shell'),
      backgroundColor: appSurfaceColor,
      body: SafeArea(
        child: Column(
          children: [
            _windowHeader(
              context,
              onSettings: () {
                setState(() => _dashboardSection = _DashboardSection.settings);
              },
            ),
            Expanded(
              child: Row(
                children: [
                  Container(
                    key: const ValueKey('dashboard-nav'),
                    width: 174,
                    decoration: BoxDecoration(
                      color: cardColor,
                      border: Border(right: BorderSide(color: borderColor)),
                    ),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
                      children: [
                        for (final section in _DashboardSection.values)
                          _DashboardNavButton(
                            section: section,
                            selected: section == _dashboardSection,
                            onTap: () {
                              setState(() => _dashboardSection = section);
                            },
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ColoredBox(
                      color: appSurfaceColor,
                      child: _dashboardContent(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashboardContent(BuildContext context) {
    return switch (_dashboardSection) {
      _DashboardSection.summary => ListView(
          key: const ValueKey('dashboard-section-summary'),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          children: _dashboardSummaryWidgets(context),
        ),
      _DashboardSection.heatmap => HeatmapPage(
          summary: HeatmapSummary.fromSnapshots(_controller.state.snapshots),
          onBack: () {},
          onExport: () => _exportData(context),
          onImport: () => _importData(context),
          showBackButton: false,
        ),
      _DashboardSection.problems => ProblemsPage(
          problems: _controller.state.problems,
          onBack: () {},
          onParseLink: _controller.parseProblemLink,
          onSave: _controller.saveProblem,
          onDelete: _controller.deleteProblem,
          onOpenProblem: _actions.openProblemUrl,
          showBackButton: false,
        ),
      _DashboardSection.refreshLogs => RefreshLogsPage(
          logs: _controller.state.refreshLogs,
          onBack: () {},
          showBackButton: false,
        ),
      _DashboardSection.contests => ContestsPage(
          contests: _controller.state.contests,
          rankPoints: _controller.contestRankPoints(),
          onBack: () {},
          onSave: _controller.saveContest,
          onDelete: _controller.deleteContest,
          showBackButton: false,
        ),
      _DashboardSection.teammates => TeammatesPage(
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
      _DashboardSection.ojAccounts => ListView(
          key: const ValueKey('dashboard-section-oj-accounts'),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          children: [
            const _DashboardSectionTitle(section: _DashboardSection.ojAccounts),
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
      _DashboardSection.daily => ListView(
          key: const ValueKey('dashboard-section-daily'),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          children: [
            const _DashboardSectionTitle(section: _DashboardSection.daily),
            const SizedBox(height: 10),
            DailyPanel(state: _controller.state),
          ],
        ),
      _DashboardSection.settings => _buildDashboardSettings(context),
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
      const _DashboardSectionTitle(section: _DashboardSection.summary),
      const SizedBox(height: 10),
      HomeSummaryPanel(
        viewModel: viewModel,
        onOpenSettings: () {
          setState(() => _dashboardSection = _DashboardSection.settings);
        },
        onRefresh: _controller.refreshing ? null : _controller.refresh,
        onOpenAction: _openHomeAction,
      ),
      const SizedBox(height: 16),
      SummaryPanel(state: _controller.state, viewModel: viewModel),
      const SizedBox(height: 12),
      HeatmapEntryPanel(
        summary: HeatmapSummary.fromSnapshots(_controller.state.snapshots),
        onOpen: () {
          setState(() => _dashboardSection = _DashboardSection.heatmap);
        },
        onExport: () => _exportData(context),
        onImport: () => _importData(context),
      ),
      const SizedBox(height: 12),
      ProblemsEntryPanel(
        problems: _controller.state.problems,
        onOpen: () {
          setState(() => _dashboardSection = _DashboardSection.problems);
        },
      ),
      const SizedBox(height: 12),
      RefreshLogsEntryPanel(
        logs: _controller.state.refreshLogs,
        onOpen: () {
          setState(() => _dashboardSection = _DashboardSection.refreshLogs);
        },
      ),
      const SizedBox(height: 12),
      ContestsEntryPanel(
        contests: _controller.state.contests,
        onOpen: () {
          setState(() => _dashboardSection = _DashboardSection.contests);
        },
      ),
      const SizedBox(height: 12),
      TeammatesEntryPanel(
        teammates: _controller.state.teammates,
        todayRanking: _controller.teammateTodayRanking(),
        onOpen: () {
          setState(() => _dashboardSection = _DashboardSection.teammates);
        },
      ),
      const SizedBox(height: 12),
      DailyPanel(state: _controller.state),
    ];
  }

  void _openHomeAction(HomeActionTarget target) {
    setState(() {
      _dashboardSection = switch (target) {
        HomeActionTarget.heatmap => _DashboardSection.heatmap,
        HomeActionTarget.problems => _DashboardSection.problems,
        HomeActionTarget.refreshLogs => _DashboardSection.refreshLogs,
        HomeActionTarget.contests => _DashboardSection.contests,
        HomeActionTarget.teammates => _DashboardSection.teammates,
      };
    });
  }

  Widget _buildDashboardSettings(BuildContext context) {
    final config = _controller.state.config;
    return ListView(
      key: const ValueKey('dashboard-section-settings'),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      children: [
        const _DashboardSectionTitle(section: _DashboardSection.settings),
        const SizedBox(height: 12),
        _SettingsBlock(
          children: [
            DropdownButtonFormField<CompactClickTarget>(
              key: const ValueKey('dashboard-compact-click-target-field'),
              initialValue: config.compactClickTarget,
              decoration: const InputDecoration(
                labelText: '小浮窗点击后进入',
              ),
              items: const [
                DropdownMenuItem(
                  value: CompactClickTarget.largeFloat,
                  child: Text('大浮窗'),
                ),
                DropdownMenuItem(
                  value: CompactClickTarget.dashboard,
                  child: Text('Dashboard'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  unawaited(
                    _saveConfigFromDashboard(
                      context,
                      config.copyWith(compactClickTarget: value),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<AppColorTheme>(
              key: const ValueKey('dashboard-color-theme-field'),
              initialValue: config.colorTheme,
              decoration: const InputDecoration(labelText: '配色主题'),
              items: [
                for (final theme in AppColorTheme.values)
                  DropdownMenuItem(
                    value: theme,
                    child: Text(AppLabels.colorThemeLabel(theme)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  unawaited(
                    _saveConfigFromDashboard(
                      context,
                      config.copyWith(colorTheme: value),
                    ),
                  );
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        _SettingsBlock(
          title: '大浮窗显示模块',
          children: [
            for (final module in defaultDashboardModules)
              Material(
                color: Colors.transparent,
                child: CheckboxListTile(
                  key: ValueKey('dashboard-large-module-enabled-${module.id}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(dashboardModuleIcon(module), size: 20),
                  title: Text(AppLabels.dashboardModuleLabel(module)),
                  value: config.dashboardModules.contains(module),
                  onChanged: (value) {
                    final next = _withModuleEnabled(
                      config.dashboardModules,
                      module,
                      value ?? true,
                    );
                    unawaited(
                      _saveConfigFromDashboard(
                        context,
                        config.copyWith(dashboardModules: next),
                      ),
                    );
                  },
                ),
              ),
            if (config.dashboardModules.isNotEmpty) ...[
              const Divider(height: 18),
              for (final item in config.dashboardModules.indexed)
                _DashboardModuleSortRow(
                  module: item.$2,
                  isFirst: item.$1 == 0,
                  isLast: item.$1 == config.dashboardModules.length - 1,
                  onMoveUp: () {
                    unawaited(
                      _saveConfigFromDashboard(
                        context,
                        config.copyWith(
                          dashboardModules: _moveModule(
                            config.dashboardModules,
                            item.$1,
                            -1,
                          ),
                        ),
                      ),
                    );
                  },
                  onMoveDown: () {
                    unawaited(
                      _saveConfigFromDashboard(
                        context,
                        config.copyWith(
                          dashboardModules: _moveModule(
                            config.dashboardModules,
                            item.$1,
                            1,
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        _SettingsBlock(
          title: '窗口',
          children: [
            Material(
              color: Colors.transparent,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('登录时启动'),
                value: config.launchAtStartup,
                onChanged: (value) {
                  unawaited(
                    _saveConfigFromDashboard(
                      context,
                      config.copyWith(launchAtStartup: value),
                    ),
                  );
                },
              ),
            ),
            Material(
              color: Colors.transparent,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('窗口置顶'),
                value: config.alwaysOnTop,
                onChanged: (value) {
                  unawaited(
                    _saveConfigFromDashboard(
                      context,
                      config.copyWith(alwaysOnTop: value),
                    ),
                  );
                },
              ),
            ),
            Material(
              color: Colors.transparent,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('在任务栏显示'),
                value: config.showInTaskbar,
                onChanged: (value) {
                  unawaited(
                    _saveConfigFromDashboard(
                      context,
                      config.copyWith(showInTaskbar: value),
                    ),
                  );
                },
              ),
            ),
            Material(
              color: Colors.transparent,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('关闭时隐藏到托盘'),
                value: config.closeToTray,
                onChanged: (value) {
                  unawaited(
                    _saveConfigFromDashboard(
                      context,
                      config.copyWith(closeToTray: value),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('dashboard-open-full-settings-button'),
              onPressed: () => _openSettings(context),
              icon: const Icon(Icons.tune),
              label: const Text('打开完整设置'),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _dashboardModuleWidgets(BuildContext context) {
    if (_controller.state.config.dashboardModules.isEmpty) {
      return [
        Container(
          key: const ValueKey('large-float-empty-modules'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            '大浮窗暂未显示模块，可在 Dashboard 的设置里打开。',
            style: TextStyle(color: textSecondaryColor),
          ),
        ),
      ];
    }
    return [
      for (final module in _controller.state.config.dashboardModules) ...[
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
          onOpen: () => _setMode(AppDisplayMode.problems),
        ),
      DashboardModule.refreshLogs => RefreshLogsEntryPanel(
          logs: _controller.state.refreshLogs,
          onOpen: () => _setMode(AppDisplayMode.refreshLogs),
        ),
      DashboardModule.contests => ContestsEntryPanel(
          contests: _controller.state.contests,
          onOpen: () => _setMode(AppDisplayMode.contests),
        ),
      DashboardModule.teammates => TeammatesEntryPanel(
          teammates: _controller.state.teammates,
          todayRanking: _controller.teammateTodayRanking(),
          onOpen: () => _setMode(AppDisplayMode.teammates),
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
    _setMode(AppDisplayMode.heatmap);
  }

  void _openFromCompact() {
    final target = _controller.state.config.compactClickTarget;
    _setMode(
      target == CompactClickTarget.dashboard
          ? AppDisplayMode.dashboard
          : AppDisplayMode.largeFloat,
    );
  }

  Future<void> _saveConfigFromDashboard(
    BuildContext context,
    AppConfig config,
  ) async {
    final feedback = await _actions.saveConfigFromDashboard(
      controller: _controller,
      shell: _shell,
      config: config,
      enablePlatformIntegration: widget.enablePlatformIntegration,
    );
    if (feedback != null && context.mounted) {
      _showFeedback(context, feedback);
    }
  }

  Future<void> _exportData(BuildContext context) async {
    final feedback = await _actions.exportData(_controller.state);
    if (context.mounted) {
      _showFeedback(context, feedback);
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
      final feedback = await _actions.applySettingsDialogResult(
        controller: _controller,
        shell: _shell,
        result: SettingsActionResult(
          config: result.config,
          syncToken: result.syncToken,
          syncNow: result.syncNow,
        ),
        enablePlatformIntegration: widget.enablePlatformIntegration,
      );
      if (feedback != null && context.mounted) {
        _showFeedback(context, feedback);
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

    final feedback = await _actions.importData(_controller);
    if (feedback != null && context.mounted) {
      _showFeedback(context, feedback);
    }
  }

  void _showFeedback(BuildContext context, ActionFeedback feedback) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(feedback.message)));
  }

  void _setMode(AppDisplayMode mode) {
    if (_mode == mode) {
      return;
    }
    setState(() => _mode = mode);
    if (widget.enablePlatformIntegration) {
      unawaited(_shell.syncMode(mode));
    }
  }
}

enum _DashboardSection {
  summary,
  heatmap,
  problems,
  refreshLogs,
  contests,
  teammates,
  ojAccounts,
  daily,
  settings,
}

class _DashboardNavButton extends StatelessWidget {
  const _DashboardNavButton({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  final _DashboardSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? accentColor : textSecondaryColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color:
            selected ? accentColor.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          key: ValueKey('dashboard-nav-${section.name}'),
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Icon(_sectionIcon(section), size: 19, color: color),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    _sectionLabel(section),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? textPrimaryColor : textSecondaryColor,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardSectionTitle extends StatelessWidget {
  const _DashboardSectionTitle({required this.section});

  final _DashboardSection section;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(_sectionIcon(section), color: accentColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _sectionLabel(section),
            style: TextStyle(
              color: textPrimaryColor,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsBlock extends StatelessWidget {
  const _SettingsBlock({
    this.title,
    required this.children,
  });

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: TextStyle(
                color: textPrimaryColor,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
          ],
          ...children,
        ],
      ),
    );
  }
}

class _DashboardModuleSortRow extends StatelessWidget {
  const _DashboardModuleSortRow({
    required this.module,
    required this.isFirst,
    required this.isLast,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final DashboardModule module;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(dashboardModuleIcon(module), size: 20),
        title: Text(AppLabels.dashboardModuleLabel(module)),
        trailing: SizedBox(
          width: 88,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                key: ValueKey('dashboard-large-module-up-${module.id}'),
                tooltip: '上移',
                onPressed: isFirst ? null : onMoveUp,
                icon: const Icon(Icons.arrow_upward, size: 18),
              ),
              IconButton(
                key: ValueKey('dashboard-large-module-down-${module.id}'),
                tooltip: '下移',
                onPressed: isLast ? null : onMoveDown,
                icon: const Icon(Icons.arrow_downward, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<DashboardModule> _withModuleEnabled(
  List<DashboardModule> modules,
  DashboardModule module,
  bool enabled,
) {
  final next = [...modules];
  if (enabled) {
    if (!next.contains(module)) {
      next.add(module);
    }
  } else {
    next.remove(module);
  }
  return List.unmodifiable(next);
}

List<DashboardModule> _moveModule(
  List<DashboardModule> modules,
  int index,
  int delta,
) {
  final nextIndex = index + delta;
  if (nextIndex < 0 || nextIndex >= modules.length) {
    return modules;
  }
  final next = [...modules];
  final module = next.removeAt(index);
  next.insert(nextIndex, module);
  return List.unmodifiable(next);
}

String _sectionLabel(_DashboardSection section) {
  return switch (section) {
    _DashboardSection.summary => '总览',
    _DashboardSection.heatmap =>
      AppLabels.dashboardModuleLabel(DashboardModule.heatmap),
    _DashboardSection.problems =>
      AppLabels.dashboardModuleLabel(DashboardModule.problems),
    _DashboardSection.refreshLogs =>
      AppLabels.dashboardModuleLabel(DashboardModule.refreshLogs),
    _DashboardSection.contests =>
      AppLabels.dashboardModuleLabel(DashboardModule.contests),
    _DashboardSection.teammates =>
      AppLabels.dashboardModuleLabel(DashboardModule.teammates),
    _DashboardSection.ojAccounts =>
      AppLabels.dashboardModuleLabel(DashboardModule.ojAccounts),
    _DashboardSection.daily =>
      AppLabels.dashboardModuleLabel(DashboardModule.daily),
    _DashboardSection.settings => '设置',
  };
}

IconData _sectionIcon(_DashboardSection section) {
  return switch (section) {
    _DashboardSection.summary => Icons.query_stats,
    _DashboardSection.heatmap => dashboardModuleIcon(DashboardModule.heatmap),
    _DashboardSection.problems => dashboardModuleIcon(DashboardModule.problems),
    _DashboardSection.refreshLogs =>
      dashboardModuleIcon(DashboardModule.refreshLogs),
    _DashboardSection.contests => dashboardModuleIcon(DashboardModule.contests),
    _DashboardSection.teammates =>
      dashboardModuleIcon(DashboardModule.teammates),
    _DashboardSection.ojAccounts =>
      dashboardModuleIcon(DashboardModule.ojAccounts),
    _DashboardSection.daily => dashboardModuleIcon(DashboardModule.daily),
    _DashboardSection.settings => Icons.tune,
  };
}
