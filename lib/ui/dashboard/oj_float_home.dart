import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/oj_catalog.dart';
import '../../core/solved_totals.dart';
import '../../models/app_config.dart';
import '../../models/problem_record.dart';
import '../../models/training.dart';
import '../../platform/startup_service.dart';
import '../../providers/atcoder_provider.dart';
import '../../providers/codeforces_provider.dart';
import '../../providers/leetcode_provider.dart';
import '../../providers/luogu_provider.dart';
import '../../providers/nowcoder_provider.dart';
import '../../services/heatmap_service.dart';
import '../../services/home_action_service.dart';
import '../../services/browser_import_service.dart';
import '../../services/local_store.dart';
import '../../services/oj_controller.dart';
import '../../services/refresh_service.dart';
import '../../services/window_shell_service.dart';
import '../app_theme.dart';
import '../contests/contests_entry_panel.dart';
import '../contests/contests_page.dart';
import '../heatmap/heatmap_entry_panel.dart';
import '../heatmap/heatmap_page.dart';
import '../problems/problems_entry_panel.dart';
import '../problems/problems_page.dart';
import '../refresh_logs/refresh_logs_entry_panel.dart';
import '../refresh_logs/refresh_logs_page.dart';
import '../settings/settings_page.dart';
import '../teammates/teammates_entry_panel.dart';
import '../teammates/teammates_page.dart';
import '../training/training_page.dart';
import 'dashboard_navigation.dart';
import 'dashboard_overview_layout.dart';
import 'daily_panel.dart';
import 'home_summary_panel.dart';
import 'home_summary_view_model.dart';
import 'oj_tile.dart';
import 'window_header.dart';

export 'home_summary_view_model.dart';

class OjFloatHome extends StatefulWidget {
  const OjFloatHome({
    super.key,
    this.initialConfig,
    this.startHidden = false,
    this.windowShell,
    this.enablePlatformIntegration = true,
    this.autoInitializeController = true,
  });

  final AppConfig? initialConfig;
  final bool startHidden;
  final WindowShell? windowShell;
  final bool enablePlatformIntegration;
  final bool autoInitializeController;

  @override
  State<OjFloatHome> createState() => _OjFloatHomeState();
}

class _OjFloatHomeState extends State<OjFloatHome>
    with TrayListener, WindowListener {
  late final OjController _controller;
  late final WindowShell _windowShell;
  late final HomeActionService _homeActions;
  late final BrowserImportServer _browserImportServer;
  late final BrowserImportTokenStore _browserImportTokenStore;
  final _settingsKey = GlobalKey<SettingsPageState>();

  DashboardSection _dashboardSection = DashboardSection.summary;
  String _syncToken = '';
  String _browserImportToken = '';
  String _browserImportError = '';
  bool _exiting = false;
  bool _handlingWindowClose = false;

  @override
  void initState() {
    super.initState();
    _windowShell = widget.windowShell ?? WindowShellService();
    _homeActions = HomeActionService();
    _browserImportServer = BrowserImportServer();
    _browserImportTokenStore = SecureBrowserImportTokenStore();
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
      _windowShell.addTrayListener(this);
      _windowShell.addWindowListener(this);
    }
    if (widget.autoInitializeController) {
      unawaited(_initialize());
    }
  }

  Future<void> _initialize() async {
    try {
      // A silent startup must expose its tray affordance before any network
      // refresh begins, otherwise a slow provider can leave the app hidden and
      // temporarily unreachable.
      if (widget.enablePlatformIntegration && widget.initialConfig != null) {
        await _applyShellConfig(widget.initialConfig!);
      }
      await _controller.init();
      _syncToken = await _controller.loadSyncToken();
      if (widget.enablePlatformIntegration) {
        await _startBrowserImportService();
      }
      if (widget.enablePlatformIntegration && widget.initialConfig == null) {
        await _applyShellConfig(_controller.state.config);
      }
    } catch (error) {
      if (widget.enablePlatformIntegration && widget.startHidden) {
        await _windowShell.showAndFocus();
      }
      if (mounted) {
        _showFeedback('初始化失败：$error');
      }
    }
  }

  @override
  void dispose() {
    if (widget.enablePlatformIntegration) {
      _windowShell.removeTrayListener(this);
      _windowShell.removeWindowListener(this);
    }
    unawaited(_browserImportServer.stop());
    _controller.dispose();
    super.dispose();
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(_windowShell.showAndFocus());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (WindowShellTrayCommand.fromKey(menuItem.key)) {
      case WindowShellTrayCommand.show:
        await _windowShell.showAndFocus();
        break;
      case WindowShellTrayCommand.refresh:
        await _controller.refresh();
        break;
      case WindowShellTrayCommand.exit:
        await _exitApp();
        break;
      case null:
        break;
    }
  }

  @override
  void onWindowClose() {
    unawaited(_handleWindowClose());
  }

  Future<void> _handleWindowClose() async {
    if (_exiting || _handlingWindowClose) {
      return;
    }
    _handlingWindowClose = true;
    try {
      if (!await _confirmSettingsCanLeave()) {
        return;
      }
      if (_controller.state.config.closeToTray) {
        await _windowShell.hide();
      } else {
        await _exitApp(confirmUnsaved: false);
      }
    } finally {
      _handlingWindowClose = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Theme(
          data: buildAppTheme(_controller.state.config.colorTheme),
          child: DashboardShell(
            header: WindowHeader(
              sectionLabel: sectionLabel(_dashboardSection),
              refreshing: _controller.refreshing,
              onRefresh: _controller.refreshing ? null : _controller.refresh,
              onSettings: () => unawaited(
                _selectSection(DashboardSection.settings),
              ),
            ),
            currentSection: _dashboardSection,
            onSectionSelected: (section) => unawaited(_selectSection(section)),
            child: _dashboardContent(context),
          ),
        );
      },
    );
  }

  Future<void> _selectSection(DashboardSection section) async {
    if (section == _dashboardSection) {
      return;
    }
    if (_dashboardSection == DashboardSection.settings) {
      final canLeave = await _confirmSettingsCanLeave();
      if (!canLeave) {
        return;
      }
    }
    if (mounted) {
      setState(() => _dashboardSection = section);
    }
  }

  Widget _dashboardContent(BuildContext context) {
    return switch (_dashboardSection) {
      DashboardSection.summary => ListView(
          key: const ValueKey('dashboard-section-summary'),
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          children: _dashboardSummaryWidgets(context),
        ),
      DashboardSection.training => TrainingPage(
          problems: _controller.state.problems,
          contests: _controller.state.contests,
          training: _controller.state.training,
          analytics: _controller.trainingAnalytics(),
          onStart: _startTraining,
          onPause: _controller.pauseTraining,
          onResume: _controller.resumeTraining,
          onCancel: _controller.cancelTraining,
          onFinish: _finishTraining,
          onAddTasks: _controller.addProblemsToSchedule,
          onMoveTask: _controller.moveTrainingTask,
          onRemoveTask: _controller.removeTrainingTask,
          onSaveList: _controller.saveTrainingList,
          onDeleteList: _controller.deleteTrainingList,
          onOpenProblem: _openProblemUrl,
        ),
      DashboardSection.heatmap => HeatmapPage(
          summary: HeatmapSummary.fromSnapshots(_controller.state.snapshots),
          onBack: () {},
          onExport: () => _exportData(),
          onImport: _importData,
          showBackButton: false,
        ),
      DashboardSection.problems => ProblemsPage(
          problems: _controller.state.problems,
          onBack: () {},
          onParseLink: _controller.parseProblemLink,
          onSave: _controller.saveProblem,
          onDelete: _controller.deleteProblem,
          onOpenProblem: (problem) => _startTraining(problem, null),
          onRestore: _controller.restoreProblem,
          onPermanentDelete: _controller.permanentlyDeleteProblem,
          onStartTraining: (problem) => _startTraining(problem, null),
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
                accountActivity: _controller.todayActivityByAccountFor(meta.id),
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
      DashboardSection.settings => SettingsPage(
          key: _settingsKey,
          config: _controller.state.config,
          initialSyncToken: _syncToken,
          browserImportToken: _browserImportToken,
          browserImportRunning: _browserImportServer.isRunning,
          browserImportPort:
              _browserImportServer.boundPort ?? defaultBrowserImportPort,
          browserImportError: _browserImportError,
          onRotateBrowserImportToken: _rotateBrowserImportToken,
          onSave: _saveSettings,
        ),
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
          onOpenSettings: () => unawaited(
            _selectSection(DashboardSection.settings),
          ),
          onRefresh: _controller.refreshing ? null : _controller.refresh,
          onOpenAction: _openHomeAction,
        ),
        aside: [
          HeatmapEntryPanel(
            summary: HeatmapSummary.fromSnapshots(_controller.state.snapshots),
            onOpen: () => unawaited(
              _selectSection(DashboardSection.heatmap),
            ),
            onExport: _exportData,
            onImport: _importData,
          ),
          ProblemsEntryPanel(
            problems: _controller.state.problems,
            onOpen: () => unawaited(
              _selectSection(DashboardSection.problems),
            ),
          ),
          RefreshLogsEntryPanel(
            logs: _controller.state.refreshLogs,
            onOpen: () => unawaited(
              _selectSection(DashboardSection.refreshLogs),
            ),
          ),
        ],
        bottom: [
          ContestsEntryPanel(
            contests: _controller.state.contests,
            onOpen: () => unawaited(
              _selectSection(DashboardSection.contests),
            ),
          ),
          TeammatesEntryPanel(
            teammates: _controller.state.teammates,
            todayRanking: _controller.teammateTodayRanking(),
            onOpen: () => unawaited(
              _selectSection(DashboardSection.teammates),
            ),
          ),
          DailyPanel(state: _controller.state),
        ],
      ),
    ];
  }

  void _openHomeAction(HomeActionTarget target) {
    final section = switch (target) {
      HomeActionTarget.training => DashboardSection.training,
      HomeActionTarget.heatmap => DashboardSection.heatmap,
      HomeActionTarget.problems => DashboardSection.problems,
      HomeActionTarget.refreshLogs => DashboardSection.refreshLogs,
      HomeActionTarget.contests => DashboardSection.contests,
      HomeActionTarget.teammates => DashboardSection.teammates,
    };
    unawaited(_selectSection(section));
  }

  Future<void> _saveSettings(SettingsPageResult result) async {
    await _homeActions.saveSettings(
      controller: _controller,
      shell: _windowShell,
      config: result.config,
      syncToken: result.syncToken,
      syncNow: result.syncNow,
      enablePlatformIntegration: widget.enablePlatformIntegration,
    );
    if (mounted) {
      setState(() => _syncToken = result.syncToken);
    } else {
      _syncToken = result.syncToken;
    }
  }

  Future<void> _applyShellConfig(AppConfig config) async {
    try {
      if (config.closeToTray) {
        await _windowShell.setTrayEnabled(true);
      } else {
        await _windowShell.setTrayEnabled(false);
      }
      await _windowShell.setCloseInterceptionEnabled(true);
    } catch (error) {
      await _windowShell.setCloseInterceptionEnabled(true);
      await _windowShell.setTrayEnabled(false);
      await _windowShell.showAndFocus();
      final fallback = config.copyWith(
        closeToTray: false,
        launchAtStartup: false,
      );
      await _controller.saveConfig(fallback);
      rethrow;
    }
  }

  Future<void> _exportData() async {
    final feedback = await _homeActions.exportData(_controller.state);
    if (mounted) {
      _showFeedback(feedback.message);
    }
  }

  Future<void> _importData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入备份'),
        content: const Text('导入会覆盖当前配置和本地数据，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('继续导入'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final feedback = await _homeActions.importData(_controller);
    if (feedback == null || !mounted) {
      return;
    }
    if (feedback.isSuccess && widget.enablePlatformIntegration) {
      await _applyShellConfig(_controller.state.config);
    }
    _showFeedback(feedback.message);
  }

  Future<void> _openProblemUrl(ProblemRecord problem) async {
    try {
      await _homeActions.openProblemUrl(problem);
    } catch (error) {
      if (mounted) {
        _showFeedback('打开题目失败：$error');
      }
    }
  }

  Future<void> _startTraining(
    ProblemRecord problem,
    String? taskId,
  ) async {
    var started = false;
    try {
      await _controller.startTraining(
        problem.id,
        origin: TrainingAttemptOrigin.manual,
        taskId: taskId,
      );
      started = true;
      await _homeActions.openProblemUrl(problem);
    } catch (error) {
      if (started &&
          _controller.state.training.activeAttempt?.problemId == problem.id) {
        await _controller.cancelTraining();
      }
      if (mounted) {
        _showFeedback('开始训练失败：${normalizeError(error)}');
      }
    }
  }

  Future<void> _finishTraining(TrainingFinishInput input) async {
    try {
      await _controller.finishTraining(
        result: input.result,
        assistance: input.assistance,
        mistakes: input.mistakes,
        reflection: input.reflection,
        favoriteListId: input.favoriteListId,
      );
      if (mounted) {
        _showFeedback('训练记录已保存');
      }
    } catch (error) {
      if (mounted) {
        _showFeedback('保存训练记录失败：${normalizeError(error)}');
      }
    }
  }

  Future<void> _startBrowserImportService() async {
    try {
      final token = await _browserImportTokenStore.getOrCreateToken();
      await _browserImportServer.start(
        token: token,
        importer: _controller.importBrowserProblem,
      );
      if (mounted) {
        setState(() {
          _browserImportToken = token;
          _browserImportError = '';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _browserImportError = normalizeError(error);
        });
      }
    }
  }

  Future<void> _rotateBrowserImportToken() async {
    try {
      final token = await _browserImportTokenStore.rotateToken();
      if (_browserImportServer.isRunning) {
        await _browserImportServer.updateToken(token);
      } else {
        await _browserImportServer.start(
          token: token,
          importer: _controller.importBrowserProblem,
        );
      }
      if (mounted) {
        setState(() {
          _browserImportToken = token;
          _browserImportError = '';
        });
        _showFeedback('浏览器配对令牌已更新');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _browserImportError = normalizeError(error));
        _showFeedback('浏览器导入服务启动失败：${normalizeError(error)}');
      }
    }
  }

  void _showFeedback(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirmSettingsCanLeave() async {
    if (_dashboardSection != DashboardSection.settings) {
      return true;
    }
    return await _settingsKey.currentState?.confirmCanLeave() ?? true;
  }

  Future<void> _exitApp({bool confirmUnsaved = true}) async {
    if (_exiting) {
      return;
    }
    if (confirmUnsaved && !await _confirmSettingsCanLeave()) {
      return;
    }
    _exiting = true;
    try {
      await _windowShell.exitApp();
    } catch (error) {
      _exiting = false;
      if (mounted) {
        _showFeedback('退出客户端失败：$error');
      }
    }
  }
}
