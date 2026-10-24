import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/oj_catalog.dart';
import '../../models/app_config.dart';
import '../../models/quick_entry_shortcut.dart';
import '../../services/diagnostics_service.dart';
import '../app_theme.dart';
import '../shared/app_surface_card.dart';
import '../shared/app_page_header.dart';
import 'dashboard_customization.dart';
import 'appearance_settings.dart';
import 'app_update_settings.dart';
import 'companion_connection_panel.dart';

class SettingsPageResult {
  const SettingsPageResult({
    required this.config,
    required this.syncToken,
    required this.syncNow,
  });

  final AppConfig config;
  final String syncToken;
  final bool syncNow;
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.config,
    required this.initialSyncToken,
    required this.onSave,
    this.onExport,
    this.onImport,
    this.browserImportToken = '',
    this.browserImportRunning = false,
    this.browserImportPort = 27121,
    this.browserImportError = '',
    this.onRotateBrowserImportToken,
    this.onChooseAutomaticBackupDirectory,
    this.automaticBackupLastSuccessAt,
    this.automaticBackupLastPath,
    this.automaticBackupError = '',
  });

  final VoidCallback? onExport;
  final VoidCallback? onImport;
  final AppConfig config;
  final String initialSyncToken;
  final Future<void> Function(SettingsPageResult result) onSave;
  final String browserImportToken;
  final bool browserImportRunning;
  final int browserImportPort;
  final String browserImportError;
  final Future<void> Function()? onRotateBrowserImportToken;
  final Future<String?> Function()? onChooseAutomaticBackupDirectory;
  final DateTime? automaticBackupLastSuccessAt;
  final String? automaticBackupLastPath;
  final String automaticBackupError;

  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _intervalController;
  late final TextEditingController _syncEndpointController;
  late final TextEditingController _syncTokenController;
  late final TextEditingController _quickEntryHotkeyController;
  late final Map<String, TextEditingController> _accountControllers;
  late final Map<String, bool> _accountEnabled;

  late bool _closeToTray;
  late bool _launchAtStartup;
  late bool _syncEnabled;
  late bool _syncDailyStats;
  late bool _syncProblems;
  late bool _includeProblemNote;
  late bool _includeProblemAnalysis;
  late bool _autoSyncAfterRefresh;
  late bool _automaticBackupEnabled;
  late AppColorTheme _colorTheme;
  late List<DashboardModule> _dashboardModules;
  late List<DashboardModule> _dashboardOrder;
  late List<DashboardModule> _wideDashboardModules;
  late AppAppearanceMode _appearanceMode;
  late bool _compactDensity;
  late TimeOfDay _automaticBackupTime;
  late String _automaticBackupDirectoryPath;

  bool _dirty = false;
  bool _saving = false;
  final _browserSectionKey = GlobalKey();
  final _accountsSectionKey = GlobalKey();

  Future<void> revealSetup({required bool accounts}) async {
    final target =
        (accounts ? _accountsSectionKey : _browserSectionKey).currentContext;
    if (target != null) {
      await Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 180),
        alignment: 0,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _intervalController = TextEditingController(
      text: '${widget.config.refreshIntervalMinutes}',
    );
    _syncEndpointController = TextEditingController(
      text: widget.config.sync.endpointUrl,
    );
    _syncTokenController = TextEditingController(text: widget.initialSyncToken);
    _quickEntryHotkeyController = TextEditingController(
      text: widget.config.quickEntryHotkey,
    );
    _accountControllers = {
      for (final meta in supportedOjs)
        meta.id: TextEditingController(
          text: widget.config.accounts[meta.id]?.usernames.join(', ') ?? '',
        ),
    };
    _accountEnabled = {
      for (final meta in supportedOjs)
        meta.id: widget.config.accounts[meta.id]?.enabled ?? false,
    };
    _closeToTray = widget.config.closeToTray;
    _launchAtStartup = widget.config.launchAtStartup && _closeToTray;
    _syncEnabled = widget.config.sync.enabled;
    _syncDailyStats = widget.config.sync.syncDailyStats;
    _syncProblems = widget.config.sync.syncProblems;
    _includeProblemNote = widget.config.sync.includeProblemNote;
    _includeProblemAnalysis = widget.config.sync.includeProblemAnalysis;
    _autoSyncAfterRefresh = widget.config.sync.autoSyncAfterRefresh;
    _automaticBackupEnabled = widget.config.automaticBackup.enabled;
    _colorTheme = widget.config.colorTheme;
    _restoreWorkspaceValues();
    _automaticBackupTime = TimeOfDay(
      hour: widget.config.automaticBackup.timeMinutes ~/ 60,
      minute: widget.config.automaticBackup.timeMinutes % 60,
    );
    _automaticBackupDirectoryPath = widget.config.automaticBackup.directoryPath;
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config != widget.config && !_dirty && !_saving) {
      _restoreSavedValues();
    }
  }

  @override
  void dispose() {
    _intervalController.dispose();
    _syncEndpointController.dispose();
    _syncTokenController.dispose();
    _quickEntryHotkeyController.dispose();
    for (final controller in _accountControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<bool> confirmCanLeave() async {
    if (!_dirty || !mounted) {
      return true;
    }
    final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('放弃未保存的更改？'),
            content: const Text('关闭或离开设置页后，本次修改不会保留。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('继续编辑'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('放弃更改'),
              ),
            ],
          ),
        ) ??
        false;
    if (discard && mounted) {
      _restoreSavedValues();
    }
    return discard;
  }

  void _restoreSavedValues() {
    _intervalController.text = '${widget.config.refreshIntervalMinutes}';
    _syncEndpointController.text = widget.config.sync.endpointUrl;
    _syncTokenController.text = widget.initialSyncToken;
    for (final meta in supportedOjs) {
      _accountControllers[meta.id]!.text =
          widget.config.accounts[meta.id]?.usernames.join(', ') ?? '';
      _accountEnabled[meta.id] =
          widget.config.accounts[meta.id]?.enabled ?? false;
    }
    setState(() {
      _closeToTray = widget.config.closeToTray;
      _launchAtStartup =
          widget.config.launchAtStartup && widget.config.closeToTray;
      _syncEnabled = widget.config.sync.enabled;
      _syncDailyStats = widget.config.sync.syncDailyStats;
      _syncProblems = widget.config.sync.syncProblems;
      _includeProblemNote = widget.config.sync.includeProblemNote;
      _includeProblemAnalysis = widget.config.sync.includeProblemAnalysis;
      _autoSyncAfterRefresh = widget.config.sync.autoSyncAfterRefresh;
      _automaticBackupEnabled = widget.config.automaticBackup.enabled;
      _colorTheme = widget.config.colorTheme;
      _restoreWorkspaceValues();
      _quickEntryHotkeyController.text = widget.config.quickEntryHotkey;
      _automaticBackupTime = TimeOfDay(
        hour: widget.config.automaticBackup.timeMinutes ~/ 60,
        minute: widget.config.automaticBackup.timeMinutes % 60,
      );
      _automaticBackupDirectoryPath =
          widget.config.automaticBackup.directoryPath;
      _dirty = false;
    });
  }

  void _restoreWorkspaceValues() {
    _dashboardModules = [...widget.config.dashboardModules];
    _dashboardOrder = [...widget.config.dashboardOrder];
    _wideDashboardModules = [...widget.config.wideDashboardModules];
    _appearanceMode = widget.config.appearanceMode;
    _compactDensity = widget.config.compactDensity;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('dashboard-section-settings'),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: appSpace4),
                _SettingsSection(
                  icon: Icons.palette_outlined,
                  title: '外观',
                  subtitle: '挑选喜欢的配色，调整明暗与内容密度。保存后应用。',
                  child: AppearanceSettings(
                    colorTheme: _colorTheme,
                    appearanceMode: _appearanceMode,
                    compactDensity: _compactDensity,
                    onThemeChanged: (value) => setState(() {
                      _colorTheme = value;
                      _dirty = true;
                    }),
                    onModeChanged: (value) => setState(() {
                      _appearanceMode = value;
                      _dirty = true;
                    }),
                    onDensityChanged: (value) => setState(() {
                      _compactDensity = value;
                      _dirty = true;
                    }),
                  ),
                ),
                const SizedBox(height: appSpace4),
                _SettingsSection(
                  icon: Icons.schedule_outlined,
                  title: '常规',
                  subtitle: '控制自动刷新频率和客户端后台行为',
                  child: Column(
                    children: [
                      TextField(
                        key: const ValueKey('quick-entry-hotkey-field'),
                        controller: _quickEntryHotkeyController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: '快速录入快捷键',
                          hintText: '例如 Ctrl+Shift+O、Alt+Shift+Q',
                          helperText:
                              '保存后立即重新注册；冲突时可修改。至少包含 Ctrl 或 Alt + 一个字母或数字，可加 Shift',
                        ),
                        onChanged: (_) => _markDirty(),
                      ),
                      const SizedBox(height: appSpace3),
                      TextField(
                        key: const ValueKey('refresh-interval-field'),
                        controller: _intervalController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '自动刷新间隔',
                          suffixText: '分钟',
                          helperText: '允许范围为 15 至 1440 分钟',
                        ),
                        onChanged: (_) => _markDirty(),
                      ),
                      const SizedBox(height: appSpace2),
                      SwitchListTile(
                        key: const ValueKey('close-to-tray-switch'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('关闭窗口时留在托盘'),
                        subtitle: const Text('关闭按钮隐藏窗口，后台继续按计划刷新'),
                        value: _closeToTray,
                        onChanged: (value) {
                          setState(() {
                            _closeToTray = value;
                            if (!value) {
                              _launchAtStartup = false;
                            }
                            _dirty = true;
                          });
                        },
                      ),
                      SwitchListTile(
                        key: const ValueKey('launch-at-startup-switch'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('登录时启动'),
                        subtitle: Text(
                          _closeToTray ? '登录 Windows 后静默进入托盘' : '需要先开启关闭到托盘',
                        ),
                        value: _launchAtStartup,
                        onChanged: _closeToTray
                            ? (value) {
                                setState(() {
                                  _launchAtStartup = value;
                                  _dirty = true;
                                });
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: appSpace4),
                AppSurfaceCard(
                  child: ExpansionTile(
                    key: const ValueKey('dashboard-customization-section'),
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      '桌面与功能',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      '${_dashboardModules.length} 个功能区已开启 · '
                      '开关、排序和宽度',
                    ),
                    leading: const Icon(Icons.dashboard_customize_outlined),
                    children: [
                      const SizedBox(height: appSpace3),
                      DashboardCustomization(
                        enabled: _dashboardModules,
                        order: _dashboardOrder,
                        wide: _wideDashboardModules,
                        onEnabledChanged: (value) => setState(() {
                          _dashboardModules = value;
                          _dirty = true;
                        }),
                        onOrderChanged: (value) => setState(() {
                          _dashboardOrder = value;
                          _dirty = true;
                        }),
                        onWideChanged: (value) => setState(() {
                          _wideDashboardModules = value;
                          _dirty = true;
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: appSpace4),
                _SettingsSection(
                  icon: Icons.backup_outlined,
                  title: '自动备份',
                  subtitle: '仅备份题目、题单、每日安排、训练复盘和比赛复盘',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SwitchListTile(
                        key: const ValueKey('automatic-backup-switch'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('启用轮换自动备份'),
                        subtitle: const Text('应用运行时按设定时间备份；每天最多一份'),
                        value: _automaticBackupEnabled,
                        onChanged: (value) {
                          setState(() {
                            _automaticBackupEnabled = value;
                            _dirty = true;
                          });
                        },
                      ),
                      const SizedBox(height: appSpace2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '备份时间',
                              style: TextStyle(
                                color: textPrimaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            key: const ValueKey('automatic-backup-time-button'),
                            onPressed: _automaticBackupEnabled
                                ? _pickAutomaticBackupTime
                                : null,
                            icon: const Icon(Icons.schedule_outlined),
                            label: Text(
                              _formatBackupTime(_automaticBackupTime),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: appSpace3),
                      Text(
                        '保存位置',
                        style: TextStyle(
                          color: textPrimaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        _automaticBackupDirectoryPath.isEmpty
                            ? '尚未确定备份目录'
                            : _automaticBackupDirectoryPath,
                        key: const ValueKey('automatic-backup-directory-path'),
                        style: TextStyle(
                          color: textSecondaryColor,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: appSpace2),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          key: const ValueKey(
                            'choose-automatic-backup-directory',
                          ),
                          onPressed:
                              widget.onChooseAutomaticBackupDirectory == null
                                  ? null
                                  : _chooseAutomaticBackupDirectory,
                          icon: const Icon(Icons.folder_open_outlined),
                          label: const Text('选择文件夹'),
                        ),
                      ),
                      const SizedBox(height: appSpace2),
                      Text(
                        '保留最近 7 个备份日，并额外保留更早的最近 4 周各一份。'
                        '导入前安全备份也保存在此目录，但不会被自动删除。',
                        style: TextStyle(
                          color: textSecondaryColor,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                      if (widget.automaticBackupLastSuccessAt != null) ...[
                        const SizedBox(height: appSpace2),
                        Text(
                          '上次有效备份：${_formatBackupDateTime(widget.automaticBackupLastSuccessAt!)}',
                          key: const ValueKey('automatic-backup-last-success'),
                          style: TextStyle(
                            color: textSecondaryColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (widget.automaticBackupLastPath?.isNotEmpty ==
                          true) ...[
                        const SizedBox(height: 4),
                        SelectableText(
                          widget.automaticBackupLastPath!,
                          key: const ValueKey('automatic-backup-last-path'),
                          style: TextStyle(
                            color: textSecondaryColor,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      if (widget.onExport != null ||
                          widget.onImport != null) ...[
                        const SizedBox(height: appSpace3),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (widget.onExport != null)
                              OutlinedButton.icon(
                                key: const ValueKey('settings-export-backup'),
                                onPressed: widget.onExport,
                                icon: const Icon(Icons.download_outlined),
                                label: const Text('导出完整备份'),
                              ),
                            if (widget.onImport != null)
                              OutlinedButton.icon(
                                key: const ValueKey('settings-import-backup'),
                                onPressed: widget.onImport,
                                icon: const Icon(Icons.restore_outlined),
                                label: const Text('导入备份'),
                              ),
                          ],
                        ),
                      ],
                      if (widget.automaticBackupError.isNotEmpty) ...[
                        const SizedBox(height: appSpace2),
                        Text(
                          widget.automaticBackupError,
                          key: const ValueKey('automatic-backup-error'),
                          style: TextStyle(
                            color: dangerColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: appSpace4),
                _SettingsSection(
                  icon: Icons.bug_report_outlined,
                  title: '诊断信息',
                  subtitle: '导出脱敏后的诊断日志，用于排查刷新、导入或恢复失败',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '导出内容仅包含应用版本、配置与数据库 schema 版本、最近操作摘要和诊断日志。'
                        '密码、令牌、Cookie、请求头、原始响应、题库正文、笔记和复盘不会记录；'
                        'OJ 账号、URL 查询参数和绝对路径中的本机用户名会替换为稳定别名。',
                        style: TextStyle(
                          color: textSecondaryColor,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: appSpace3),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          key: const ValueKey('export-diagnostics-button'),
                          onPressed: _exportDiagnostics,
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('导出诊断信息'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: appSpace4),
                _SettingsSection(
                  key: _browserSectionKey,
                  icon: Icons.extension_outlined,
                  title: '浏览器导入',
                  subtitle: '推荐使用题库小程序与油猴脚本，原有扩展也继续可用',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const CompanionConnectionPanel(),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      const Text('完整客户端扩展 · Edge / Chrome'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            widget.browserImportRunning
                                ? Icons.check_circle_outline
                                : Icons.error_outline,
                            color: widget.browserImportRunning
                                ? accentColor
                                : dangerColor,
                          ),
                          const SizedBox(width: appSpace2),
                          Expanded(
                            child: Text(
                              widget.browserImportRunning
                                  ? '本地服务运行中 · 127.0.0.1:${widget.browserImportPort}'
                                  : widget.browserImportError.isEmpty
                                      ? '本地服务未启动'
                                      : '启动失败：${widget.browserImportError}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: appSpace3),
                      Text(
                        '配对令牌',
                        style: TextStyle(
                          color: textSecondaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(appSpace3),
                        decoration: BoxDecoration(
                          color: cardMutedColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: SelectableText(
                          widget.browserImportToken.isEmpty
                              ? '服务启动后生成'
                              : widget.browserImportToken,
                          key: const ValueKey('browser-import-token'),
                        ),
                      ),
                      const SizedBox(height: appSpace2),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          key: const ValueKey('rotate-browser-import-token'),
                          tooltip: '重新生成配对令牌',
                          onPressed: widget.onRotateBrowserImportToken == null
                              ? null
                              : () async {
                                  await widget.onRotateBrowserImportToken!();
                                },
                          icon: const Icon(Icons.refresh),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: appSpace4),
                _SettingsSection(
                  icon: Icons.sync_outlined,
                  title: '网页钩子同步',
                  subtitle: '控制刷新后发送的公开训练数据',
                  child: Column(
                    children: [
                      SwitchListTile(
                        key: const ValueKey('sync-enabled-switch'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('启用网页钩子同步'),
                        value: _syncEnabled,
                        onChanged: (value) {
                          setState(() {
                            _syncEnabled = value;
                            _dirty = true;
                          });
                        },
                      ),
                      TextField(
                        key: const ValueKey('sync-endpoint-field'),
                        controller: _syncEndpointController,
                        enabled: _syncEnabled,
                        decoration: const InputDecoration(
                          labelText: '同步地址',
                          hintText: 'https://example.com/api/oj-sync',
                        ),
                        onChanged: (_) => _markDirty(),
                      ),
                      const SizedBox(height: appSpace2),
                      TextField(
                        key: const ValueKey('sync-token-field'),
                        controller: _syncTokenController,
                        enabled: _syncEnabled,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: '同步密钥'),
                        onChanged: (_) => _markDirty(),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('每日日期和总通过数'),
                        value: _syncDailyStats,
                        onChanged: _syncEnabled
                            ? (value) {
                                setState(() {
                                  _syncDailyStats = value ?? true;
                                  _dirty = true;
                                });
                              }
                            : null,
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('题目标题、链接、平台、状态和标签'),
                        value: _syncProblems,
                        onChanged: _syncEnabled
                            ? (value) {
                                setState(() {
                                  _syncProblems = value ?? true;
                                  _dirty = true;
                                });
                              }
                            : null,
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('包含题目备注'),
                        subtitle: const Text('可能包含敏感信息，默认关闭'),
                        value: _includeProblemNote,
                        onChanged: _syncEnabled && _syncProblems
                            ? (value) {
                                setState(() {
                                  _includeProblemNote = value ?? false;
                                  _dirty = true;
                                });
                              }
                            : null,
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('包含题解分析'),
                        subtitle: const Text('高度敏感，默认关闭'),
                        value: _includeProblemAnalysis,
                        onChanged: _syncEnabled && _syncProblems
                            ? (value) {
                                setState(() {
                                  _includeProblemAnalysis = value ?? false;
                                  _dirty = true;
                                });
                              }
                            : null,
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('刷新后自动同步'),
                        value: _autoSyncAfterRefresh,
                        onChanged: _syncEnabled
                            ? (value) {
                                setState(() {
                                  _autoSyncAfterRefresh = value ?? true;
                                  _dirty = true;
                                });
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: appSpace4),
                _SettingsSection(
                  key: _accountsSectionKey,
                  icon: Icons.account_circle_outlined,
                  title: 'OJ 账号',
                  subtitle: '启用需要统计的平台，并填写公开用户名或 ID',
                  child: Column(
                    children: [
                      for (final meta in supportedOjs)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Checkbox(
                                key: ValueKey('account-enabled-${meta.id}'),
                                value: _accountEnabled[meta.id] ?? false,
                                onChanged: (value) {
                                  setState(() {
                                    _accountEnabled[meta.id] = value ?? false;
                                    _dirty = true;
                                  });
                                },
                              ),
                              SizedBox(width: 92, child: Text(meta.name)),
                              Expanded(
                                child: TextField(
                                  key: ValueKey('account-usernames-${meta.id}'),
                                  controller: _accountControllers[meta.id],
                                  decoration: InputDecoration(
                                    hintText: meta.hint,
                                    isDense: true,
                                  ),
                                  onChanged: (_) => _markDirty(),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: appSpace4),
                _buildActions(),
                const SizedBox(height: 16),
                const _SettingsSection(
                  icon: Icons.info_outline,
                  title: '关于与更新',
                  subtitle: '版本信息与安装包下载',
                  child: AppUpdateSettings(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() => AppPageHeader(
        title: '设置',
        subtitle: _dirty ? '有未保存的更改' : '让工作台适合你的训练习惯。',
      );

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton.icon(
          key: const ValueKey('settings-save-sync-button'),
          onPressed:
              _saving || !_syncEnabled ? null : () => _save(syncNow: true),
          icon: const Icon(Icons.sync),
          label: const Text('保存并立即同步'),
        ),
        const SizedBox(width: appSpace2),
        FilledButton.icon(
          key: const ValueKey('settings-save-button'),
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_saving ? '保存中' : '保存设置'),
        ),
      ],
    );
  }

  void _markDirty() {
    if (!_dirty) {
      setState(() => _dirty = true);
    }
  }

  Future<void> _save({bool syncNow = false}) async {
    final interval = int.tryParse(_intervalController.text.trim());
    if (interval == null || interval < 15 || interval > 1440) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('自动刷新间隔必须在 15 至 1440 分钟之间。')),
      );
      return;
    }

    final shortcut = QuickEntryShortcut.parse(_quickEntryHotkeyController.text);
    if (shortcut == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '快捷键需要 Ctrl 或 Alt，加一个字母或数字；可同时加 Shift，例如 Ctrl+Shift+O。',
          ),
        ),
      );
      return;
    }

    final accounts = {
      for (final meta in supportedOjs)
        meta.id: OjAccountConfig(
          usernames: OjAccountConfig.normalizeUsernames([
            _accountControllers[meta.id]!.text,
          ]),
          enabled: _accountEnabled[meta.id] ?? false,
        ),
    };
    if (_automaticBackupEnabled &&
        _automaticBackupDirectoryPath.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先选择自动备份文件夹。')));
      return;
    }
    final config = widget.config.copyWith(
      refreshIntervalMinutes: interval,
      colorTheme: _colorTheme,
      dashboardModules: _dashboardModules,
      dashboardOrder: _dashboardOrder,
      wideDashboardModules: _wideDashboardModules,
      appearanceMode: _appearanceMode,
      compactDensity: _compactDensity,
      quickEntryHotkey: shortcut.label,
      accounts: accounts,
      closeToTray: _closeToTray,
      launchAtStartup: _closeToTray && _launchAtStartup,
      automaticBackup: AutomaticBackupConfig(
        enabled: _automaticBackupEnabled,
        timeMinutes:
            _automaticBackupTime.hour * 60 + _automaticBackupTime.minute,
        directoryPath: _automaticBackupDirectoryPath,
      ),
      sync: SyncConfig(
        enabled: _syncEnabled,
        endpointUrl: _syncEndpointController.text.trim(),
        syncDailyStats: _syncDailyStats,
        syncProblems: _syncProblems,
        includeProblemNote: _includeProblemNote,
        includeProblemAnalysis: _includeProblemAnalysis,
        autoSyncAfterRefresh: _autoSyncAfterRefresh,
      ),
    );

    setState(() => _saving = true);
    try {
      await widget.onSave(
        SettingsPageResult(
          config: config,
          syncToken: _syncTokenController.text,
          syncNow: syncNow,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _dirty = false;
        _quickEntryHotkeyController.text = shortcut.label;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(syncNow ? '设置已保存并完成同步。' : '设置已保存。')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存设置失败：$error')));
    }
  }

  Future<void> _pickAutomaticBackupTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _automaticBackupTime,
      helpText: '选择每日自动备份时间',
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _automaticBackupTime = selected;
      _dirty = true;
    });
  }

  Future<void> _chooseAutomaticBackupDirectory() async {
    final selected = await widget.onChooseAutomaticBackupDirectory?.call();
    if (selected == null || selected.trim().isEmpty || !mounted) {
      return;
    }
    setState(() {
      _automaticBackupDirectoryPath = selected.trim();
      _dirty = true;
    });
  }

  Future<void> _exportDiagnostics() async {
    final diagnostics = DiagnosticsService.instance ?? DiagnosticsService();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('导出诊断信息？'),
            content: const Text(
              '导出文件包含：应用版本、配置与数据库 schema 版本、'
              '最近刷新/导入/恢复操作摘要和脱敏后的诊断日志。\n\n'
              '已脱敏：密码、令牌、Cookie、请求头、原始响应、题库正文、'
              '笔记与复盘不会记录；OJ 账号、URL 查询参数和绝对路径中的'
              '本机用户名会替换为稳定别名。\n\n'
              '导出仅写入你选择的本地文件，不会自动上传或发送给任何人。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('选择位置并导出'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed != true || !mounted) return;

    final path = await FilePicker.platform.saveFile(
      dialogTitle: '导出诊断信息',
      fileName: 'oj-diagnostics.txt',
      type: FileType.custom,
      allowedExtensions: const ['txt'],
    );
    if (path == null || !mounted) return;

    try {
      await diagnostics.exportTo(File(path));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('诊断信息已导出到 $path')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('导出诊断信息失败：$error')));
    }
  }
}

String _formatBackupTime(TimeOfDay time) {
  return '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}

String _formatBackupDateTime(DateTime time) {
  final local = time.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppSurfaceCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 20),
              const SizedBox(width: appSpace2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textPrimaryColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: textSecondaryColor, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: appSpace3),
          child,
        ],
      ),
    );
  }
}
