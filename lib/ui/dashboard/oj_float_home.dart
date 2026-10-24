import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import '../problems/quick_entry_view.dart';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:url_launcher/url_launcher.dart';

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
import '../../services/browser_import_service.dart';
import '../../services/heatmap_service.dart';
import '../../services/home_action_service.dart';
import '../../services/local_store.dart';
import '../../services/data_recovery_service.dart';
import '../../services/oj_controller.dart';
import '../../services/quick_entry_hotkey_service.dart';
import '../../services/refresh_service.dart';
import '../../services/window_shell_service.dart';
import '../app_labels.dart';
import '../app_theme.dart';
import '../contests/contests_entry_panel.dart';
import '../contests/contests_page.dart';
import '../heatmap/heatmap_entry_panel.dart';
import '../heatmap/heatmap_page.dart';
import '../problems/problems_entry_panel.dart';
import '../problems/problems_page.dart';
import '../problems/problem_editor.dart';
import '../refresh_logs/refresh_logs_entry_panel.dart';
import '../refresh_logs/refresh_logs_page.dart';
import '../settings/settings_page.dart';
import '../teammates/teammates_entry_panel.dart';
import '../teammates/teammates_page.dart';
import '../training/training_page.dart';
import '../training/training_agenda_panel.dart';
import 'dashboard_navigation.dart';
import '../shared/app_surface_card.dart';
import 'daily_panel.dart';
import 'home_summary_panel.dart';
import 'home_summary_view_model.dart';
import 'oj_tile.dart';
import 'window_header.dart';
import 'startup_status_page.dart';
import 'first_run_card.dart';

export 'home_summary_view_model.dart';

class OjFloatHome extends StatefulWidget {
  const OjFloatHome({
    super.key,
    this.initialConfig,
    this.startHidden = false,
    this.windowShell,
    this.browserImportServer,
    this.enablePlatformIntegration = true,
    this.autoInitializeController = true,
    this.storage,
  });

  final AppConfig? initialConfig;
  final bool startHidden;
  final WindowShell? windowShell;
  final BrowserImportServer? browserImportServer;
  final bool enablePlatformIntegration;
  final bool autoInitializeController;
  final LocalStore? storage;

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
  static const _quickChannel = MethodChannel('oj_float/quick_entry');
  static const _hotkeyService = QuickEntryHotkeyService();
  bool _quickEntry = false;
  bool _quickTransition = false;
  Rect? _previousBounds;
  bool _previousVisible = true;
  bool _previousMaximized = false;
  bool _previousMinimized = false;
  bool _exiting = false;
  bool _handlingWindowClose = false;
  bool _ready = false;
  bool _initializing = false;
  bool _restoring = false;
  Object? _initializationError;
  bool _finishingOnboarding = false;

  @override
  void initState() {
    super.initState();
    _windowShell = widget.windowShell ?? WindowShellService();
    _homeActions = HomeActionService();
    _browserImportServer = widget.browserImportServer ?? BrowserImportServer();
    _browserImportTokenStore = SecureBrowserImportTokenStore();
    _controller = OjController(
      storage: widget.storage ??
          LocalStore(
              useFilePreferences: Platform.isWindows &&
                  widget.enablePlatformIntegration &&
                  widget.autoInitializeController),
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
      problemRefreshInterval: widget.enablePlatformIntegration
          ? const Duration(seconds: 1)
          : Duration.zero,
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
    _ready = !widget.autoInitializeController;
    if (widget.autoInitializeController) {
      unawaited(_initialize());
    }
  }

  Future<void> _initialize() async {
    if (_initializing || _ready) return;
    setState(() {
      _initializing = true;
      _initializationError = null;
    });
    try {
      // A silent startup must expose its tray affordance before any network
      // refresh begins, otherwise a slow provider can leave the app hidden and
      // temporarily unreachable.
      if (widget.enablePlatformIntegration && widget.initialConfig != null) {
        try {
          await _applyShellConfig(widget.initialConfig!,
              persistFallback: false);
        } catch (error) {
          if (mounted) _showFeedback('托盘未就绪，已显示主窗口：$error');
        }
      }
      await _controller.init(refreshOnStart: false);
      if (!mounted) return;
      setState(() => _ready = true);
      if (widget.enablePlatformIntegration &&
          Platform.isWindows &&
          _controller.state.config.moduleEnabled(DashboardModule.problems)) {
        await _registerQuickEntry();
      }
      _syncToken = widget.enablePlatformIntegration
          ? await _controller.loadSyncToken()
          : '';
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
        if (_ready) {
          _showFeedback('本地数据已读取，部分桌面服务未就绪：$error');
        } else {
          setState(() => _initializationError = error);
        }
      }
    } finally {
      if (mounted) setState(() => _initializing = false);
      if (mounted && _ready) unawaited(_refreshAfterStartup());
    }
  }

  Future<void> _refreshAfterStartup() async {
    try {
      await _controller.refresh();
      if (mounted) await _controller.maybeAutoRefreshTeammates();
    } catch (error) {
      if (mounted) _showFeedback('自动刷新未完成：$error');
    }
  }

  Future<void> _restoreLocalData() async {
    final selection = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: const ['json']);
    final path = selection?.files.single.path;
    if (path == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('从备份恢复本地数据？'),
        content: const Text('先校验备份，再替换本地题库与训练记录。'
            '当前数据文件夹会完整保留。请先关闭题库小程序。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('恢复')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _restoring = true);
    try {
      final directory = await _controller.storage.recoveryDirectory();
      final retained =
          await DataRecoveryService().restore(File(path), directory);
      if (!mounted) return;
      _showFeedback('恢复完成，原始文件保留在 ${retained.path}');
      await _initialize();
    } catch (error) {
      if (mounted) setState(() => _initializationError = error);
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<void> _openDataDirectory() async {
    try {
      final directory = await _controller.storage.recoveryDirectory();
      if (!await launchUrl(directory.uri,
          mode: LaunchMode.externalApplication)) {
        throw const FileSystemException('无法打开数据文件夹。');
      }
    } catch (error) {
      if (mounted) _showFeedback('$error');
    }
  }

  @override
  void dispose() {
    if (widget.enablePlatformIntegration) {
      _windowShell.removeTrayListener(this);
      _windowShell.removeWindowListener(this);
    }
    if (widget.enablePlatformIntegration && Platform.isWindows) {
      _quickChannel.setMethodCallHandler(null);
    }
    unawaited(_stopBrowserImportServer());
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
        if (_ready) await _controller.refresh();
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
    if (_quickEntry) {
      await _closeQuickEntry();
      return;
    }
    if (_exiting || _handlingWindowClose) {
      return;
    }
    _handlingWindowClose = true;
    try {
      if (!await _confirmSettingsCanLeave()) {
        return;
      }
      if (_ready && _controller.state.config.closeToTray) {
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
          data: buildAppTheme(
            _controller.state.config.colorTheme,
            _controller.state.config.appearanceMode,
            MediaQuery.platformBrightnessOf(context),
            _controller.state.config.compactDensity,
          ),
          child: !_ready
              ? StartupStatusPage(
                  error: _initializationError,
                  restoring: _restoring,
                  onRetry: () => unawaited(_initialize()),
                  onRestore: () => unawaited(_restoreLocalData()),
                  onOpenDirectory: () => unawaited(_openDataDirectory()),
                )
              : Stack(children: [
                  Offstage(
                      offstage: _quickEntry,
                      child: OverflowBox(
                          minWidth: _quickEntry ? appWindowSize.width : null,
                          maxWidth: _quickEntry ? appWindowSize.width : null,
                          minHeight: _quickEntry ? appWindowSize.height : null,
                          maxHeight: _quickEntry ? appWindowSize.height : null,
                          child: DashboardShell(
                            header: WindowHeader(
                              sectionLabel: sectionLabel(_effectiveSection),
                              refreshing: _controller.refreshing,
                              onRefresh: _controller.refreshing ||
                                      !_controller.state.config.moduleEnabled(
                                          DashboardModule.ojAccounts)
                                  ? null
                                  : _controller.refresh,
                              quickEntryHotkey:
                                  _controller.state.config.quickEntryHotkey,
                              onQuickEntry: _controller.state.config
                                      .moduleEnabled(DashboardModule.problems)
                                  ? () => unawaited(_openQuickEntry())
                                  : null,
                              onSettings: () => unawaited(
                                _selectSection(DashboardSection.settings),
                              ),
                            ),
                            currentSection: _effectiveSection,
                            sections: _sections,
                            onSectionSelected: (section) =>
                                unawaited(_selectSection(section)),
                            child: _dashboardContent(context),
                          ))),
                  if (_quickEntry)
                    QuickEntryView(
                        onParse: _controller.parseProblemLink,
                        onSave: _controller.saveProblem,
                        onClose: () => unawaited(_closeQuickEntry())),
                ]),
        );
      },
    );
  }

  Future<void> _registerQuickEntry() async {
    _quickChannel.setMethodCallHandler((call) async {
      if (call.method == 'open' && mounted) await _openQuickEntry();
    });
    try {
      await _hotkeyService.register(_controller.state.config.quickEntryHotkey);
      if (!mounted ||
          !_controller.state.config.moduleEnabled(DashboardModule.problems)) {
        await _hotkeyService.unregister();
      }
    } catch (error) {
      if (mounted) _showFeedback('快捷键未生效：$error');
    }
  }

  Future<void> _openQuickEntry() async {
    if (!_ready ||
        _quickTransition ||
        !_controller.state.config.moduleEnabled(DashboardModule.problems)) {
      return;
    }
    if (_quickEntry) {
      if (widget.enablePlatformIntegration) await _windowShell.showAndFocus();
      return;
    }
    _quickTransition = true;
    try {
      if (widget.enablePlatformIntegration) {
        _previousVisible = await windowManager.isVisible();
        _previousMinimized = await windowManager.isMinimized();
        _previousMaximized = await windowManager.isMaximized();
        if (_previousMinimized) await windowManager.restore();
        if (_previousMaximized) await windowManager.unmaximize();
        _previousBounds = await windowManager.getBounds();
      }
      if (!mounted) return;
      setState(() => _quickEntry = true);
      if (widget.enablePlatformIntegration) {
        await windowManager.setMinimumSize(const Size(440, 400));
        await windowManager.setSize(const Size(520, 640));
        await windowManager.center();
        await _windowShell.showAndFocus();
      }
    } catch (error) {
      if (mounted) _showFeedback('打开快速录入失败：$error');
    } finally {
      _quickTransition = false;
    }
  }

  Future<void> _closeQuickEntry() async {
    if (_quickTransition) return;
    _quickTransition = true;
    try {
      if (widget.enablePlatformIntegration) {
        if (!_previousVisible) await _windowShell.hide();
        await windowManager.setMinimumSize(appMinimumWindowSize);
        if (_previousBounds != null) {
          await windowManager.setBounds(_previousBounds!);
        }
        if (_previousMaximized) await windowManager.maximize();
        if (_previousMinimized) await windowManager.minimize();
      }
      if (mounted) setState(() => _quickEntry = false);
    } finally {
      _quickTransition = false;
    }
  }

  List<DashboardSection> get _sections => [
        for (final module in _controller.state.config.dashboardOrder)
          if (_controller.state.config.moduleEnabled(module)) ...[
            sectionForModule(module),
            if (module == DashboardModule.training) DashboardSection.todos,
          ],
        DashboardSection.settings,
      ];

  DashboardSection get _effectiveSection =>
      _sections.contains(_dashboardSection)
          ? _dashboardSection
          : _sections.first;

  Future<void> _selectSection(DashboardSection section) async {
    if (!_sections.contains(section)) return;
    if (section == _effectiveSection) {
      return;
    }
    if (_effectiveSection == DashboardSection.settings) {
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
    return switch (_effectiveSection) {
      DashboardSection.summary => ListView(
          key: const ValueKey('dashboard-section-summary'),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          children: _dashboardSummaryWidgets(context),
        ),
      DashboardSection.training || DashboardSection.todos => TrainingPage(
          key: ValueKey(_effectiveSection),
          tasksOnly: _effectiveSection == DashboardSection.todos,
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
          folders: _controller.state.problemFolders,
          onCreateFolder: _controller.createProblemFolder,
          onBatch: _controller.applyProblemBatch,
          onBack: () {},
          onParseLink: _controller.parseProblemLink,
          onSave: _controller.saveProblem,
          onDelete: _controller.deleteProblem,
          onOpenProblem: _openProblemUrl,
          onToggleFavorite: _controller.toggleProblemFavorite,
          onTogglePinned: _controller.toggleProblemPinned,
          onRestore: _controller.restoreProblem,
          onPermanentDelete: _controller.permanentlyDeleteProblem,
          onStartTraining:
              _controller.state.config.moduleEnabled(DashboardModule.training)
                  ? (problem) => _startTraining(problem, null)
                  : null,
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
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
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
                snapshots: _controller.state.snapshots,
                refreshIntervalMinutes:
                    _controller.state.config.refreshIntervalMinutes,
              ),
            ),
          ],
        ),
      DashboardSection.daily => ListView(
          key: const ValueKey('dashboard-section-daily'),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
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
          onExport: _exportData,
          onImport: _importData,
          browserImportToken: _browserImportToken,
          browserImportRunning: _browserImportServer.isRunning,
          browserImportPort:
              _browserImportServer.boundPort ?? defaultBrowserImportPort,
          browserImportError: _browserImportError,
          onRotateBrowserImportToken: _rotateBrowserImportToken,
          onChooseAutomaticBackupDirectory: _chooseAutomaticBackupDirectory,
          automaticBackupLastSuccessAt:
              _controller.automaticBackupOverview?.latestBackupAt,
          automaticBackupLastPath:
              _controller.automaticBackupOverview?.latestBackupPath,
          automaticBackupError: _controller.automaticBackupError,
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
    final config = _controller.state.config;
    final panels = <DashboardModule, Widget>{
      DashboardModule.summary: HomeSummaryPanel(
        viewModel: viewModel,
        enabledActions: [
          for (final target in HomeActionTarget.values)
            if (config
                .moduleEnabled(DashboardModule.values.byName(target.name)))
              target
        ],
        onOpenSettings: () =>
            unawaited(_selectSection(DashboardSection.settings)),
        onRefresh: config.moduleEnabled(DashboardModule.ojAccounts) &&
                !_controller.refreshing
            ? _controller.refresh
            : null,
        onOpenAction: _openHomeAction,
      ),
      DashboardModule.training: TrainingAgendaPanel(
        training: _controller.state.training,
        problems: _controller.state.problems,
        onOpen: () => unawaited(_selectSection(DashboardSection.todos)),
        onStart: (problem, taskId) =>
            unawaited(_startTraining(problem, taskId)),
      ),
      DashboardModule.heatmap: HeatmapEntryPanel(
          summary: HeatmapSummary.fromSnapshots(_controller.state.snapshots),
          onOpen: () => unawaited(_selectSection(DashboardSection.heatmap)),
          onExport: _exportData,
          onImport: _importData),
      DashboardModule.problems: ProblemsEntryPanel(
          problems: _controller.state.problems,
          onOpen: () => unawaited(_selectSection(DashboardSection.problems))),
      DashboardModule.refreshLogs: RefreshLogsEntryPanel(
          logs: _controller.state.refreshLogs,
          onOpen: () =>
              unawaited(_selectSection(DashboardSection.refreshLogs))),
      DashboardModule.contests: ContestsEntryPanel(
          contests: _controller.state.contests,
          onOpen: () => unawaited(_selectSection(DashboardSection.contests))),
      DashboardModule.teammates: TeammatesEntryPanel(
          teammates: _controller.state.teammates,
          todayRanking: _controller.teammateTodayRanking(),
          onOpen: () => unawaited(_selectSection(DashboardSection.teammates))),
      DashboardModule.ojAccounts:
          _workspaceEntry(DashboardModule.ojAccounts, '查看五个平台的账号、通过数与刷新状态'),
      DashboardModule.daily: DailyPanel(state: _controller.state),
    };
    return [
      const DashboardSectionTitle(
          section: DashboardSection.summary, subtitle: '先看今天是否有进步，再继续训练与复盘。'),
      const SizedBox(height: 14),
      if (widget.autoInitializeController &&
          !config.onboardingComplete &&
          _controller.state.problems.isEmpty &&
          config.moduleEnabled(DashboardModule.problems)) ...[
        FirstRunCard(
          busy: _finishingOnboarding,
          onCreateProblem: () => unawaited(_createFirstProblem()),
          onConnectAccounts: () => unawaited(_openSetup(accounts: true)),
          onBrowserHelp: () => unawaited(_openSetup(accounts: false)),
          onSkip: () => unawaited(_finishOnboarding()),
        ),
        const SizedBox(height: 16),
      ],
      LayoutBuilder(builder: (context, constraints) {
        final halfWidth = constraints.maxWidth >= 700
            ? (constraints.maxWidth - appSpace4) / 2
            : constraints.maxWidth;
        return Wrap(spacing: appSpace4, runSpacing: appSpace4, children: [
          for (final module in config.dashboardOrder)
            if (config.moduleEnabled(module))
              SizedBox(
                  key: ValueKey('dashboard-module-${module.name}'),
                  width: module == DashboardModule.summary ||
                          config.wideDashboardModules.contains(module)
                      ? constraints.maxWidth
                      : halfWidth,
                  child: panels[module]),
        ]);
      }),
    ];
  }

  Widget _workspaceEntry(DashboardModule module, String description) =>
      AppSurfaceCard(
        child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(dashboardModuleIcon(module), color: accentColor),
            title: Text(dashboardModuleLabel(module),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(description),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () => unawaited(_selectSection(sectionForModule(module)))),
      );

  Future<void> _finishOnboarding() async {
    if (_finishingOnboarding) return;
    setState(() => _finishingOnboarding = true);
    try {
      await _controller.saveConfig(
          _controller.state.config.copyWith(onboardingComplete: true));
    } catch (error) {
      if (mounted) _showFeedback('无法保存引导状态：$error');
    } finally {
      if (mounted) setState(() => _finishingOnboarding = false);
    }
  }

  Future<void> _createFirstProblem() async {
    final problem = await showDialog<ProblemRecord>(
      context: context,
      builder: (context) => ProblemEditorDialog(
          folders: _controller.state.problemFolders,
          onParseLink: _controller.parseProblemLink),
    );
    if (problem == null || !mounted) return;
    try {
      await _controller.saveProblem(problem);
      await _finishOnboarding();
      if (mounted) await _selectSection(DashboardSection.problems);
    } catch (error) {
      if (mounted) _showFeedback('题目未能保存：$error');
    }
  }

  Future<void> _openSetup({required bool accounts}) async {
    await _selectSection(DashboardSection.settings);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) {
      await _settingsKey.currentState?.revealSetup(accounts: accounts);
    }
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
    final nativeHotkey = widget.enablePlatformIntegration && Platform.isWindows;
    // Native registration reserves the new combination before releasing the old
    // one. A conflict must not persist an unusable setting or show save success.
    if (nativeHotkey && result.config.moduleEnabled(DashboardModule.problems)) {
      await _hotkeyService.register(result.config.quickEntryHotkey);
    }
    try {
      await _homeActions.saveSettings(
        controller: _controller,
        shell: _windowShell,
        config: result.config,
        syncToken: result.syncToken,
        syncNow: result.syncNow,
        enablePlatformIntegration: widget.enablePlatformIntegration,
      );
    } catch (_) {
      // saveConfig may persist successfully then fail at startup integration.
      // Restore the registration to whichever config actually remains in state.
      if (widget.enablePlatformIntegration) {
        try {
          await _syncProblemEntrypoints();
        } catch (error) {
          if (mounted) _showFeedback('恢复快捷键失败：$error');
        }
      }
      rethrow;
    }
    if (widget.enablePlatformIntegration) {
      await _syncProblemEntrypoints();
    }
    if (mounted) {
      setState(() => _syncToken = result.syncToken);
    } else {
      _syncToken = result.syncToken;
    }
  }

  Future<void> _applyShellConfig(AppConfig config,
      {bool persistFallback = true}) async {
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
      if (persistFallback) await _controller.saveConfig(fallback);
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
    if (!await _confirmSettingsCanLeave() || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppLabels.importBackup),
        content: const Text(AppLabels.importConfirmMessage),
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
      await _syncProblemEntrypoints();
    }
    _showFeedback(feedback.message);
  }

  Future<void> _openProblemUrl(ProblemRecord problem) async {
    try {
      await _homeActions.openProblemUrl(problem);
      await _controller.markProblemOpened(problem.id);
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

  Future<void> _syncProblemEntrypoints() async {
    if (_controller.state.config.moduleEnabled(DashboardModule.problems)) {
      if (Platform.isWindows) await _registerQuickEntry();
      await _startBrowserImportService();
    } else {
      if (Platform.isWindows) await _hotkeyService.unregister();
      await _stopBrowserImportServer();
    }
  }

  Future<void> _startBrowserImportService() async {
    if (!_controller.state.config.moduleEnabled(DashboardModule.problems)) {
      return;
    }
    try {
      final token = await _browserImportTokenStore.getOrCreateToken();
      if (!mounted ||
          !_controller.state.config.moduleEnabled(DashboardModule.problems)) {
        return;
      }
      await _browserImportServer.start(
        token: token,
        importer: _controller.importBrowserProblem,
      );
      if (!mounted ||
          !_controller.state.config.moduleEnabled(DashboardModule.problems)) {
        await _stopBrowserImportServer();
        return;
      }
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
      } else if (_controller.state.config
          .moduleEnabled(DashboardModule.problems)) {
        await _browserImportServer.start(
          token: token,
          importer: _controller.importBrowserProblem,
        );
      }
      if (!mounted ||
          !_controller.state.config.moduleEnabled(DashboardModule.problems)) {
        await _stopBrowserImportServer();
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

  Future<String?> _chooseAutomaticBackupDirectory() {
    return FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择 OJ Float 自动备份文件夹',
      initialDirectory: _controller.state.config.automaticBackup.directoryPath,
    );
  }

  void _showFeedback(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirmSettingsCanLeave() async {
    if (_effectiveSection != DashboardSection.settings) {
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
      await _stopBrowserImportServer();
      await _windowShell.exitApp();
    } catch (error) {
      _exiting = false;
      if (mounted) {
        _showFeedback('退出客户端失败：$error');
      }
    }
  }

  Future<void> _stopBrowserImportServer() async {
    try {
      await _browserImportServer.stop();
    } catch (error) {
      debugPrint('Failed to stop browser import service: $error');
    }
  }
}
