import 'package:flutter/material.dart';

import '../../core/oj_catalog.dart';
import '../../models/app_config.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({
    super.key,
    required this.config,
    this.initialSyncToken = '',
  });

  final AppConfig config;
  final String initialSyncToken;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class SettingsDialogResult {
  const SettingsDialogResult({
    required this.config,
    required this.syncToken,
    this.syncNow = false,
  });

  final AppConfig config;
  final String syncToken;
  final bool syncNow;
}

class _SettingsDialogState extends State<SettingsDialog> {
  late int _intervalMinutes;
  late final Map<String, TextEditingController> _controllers;
  late final TextEditingController _syncEndpointController;
  late final TextEditingController _syncTokenController;
  late final Map<String, bool> _enabled;
  late bool _launchAtStartup;
  late bool _alwaysOnTop;
  late bool _showInTaskbar;
  late bool _closeToTray;
  late AppColorTheme _colorTheme;
  late CompactClickTarget _compactClickTarget;
  late List<DashboardModule> _dashboardModules;
  late bool _syncEnabled;
  late bool _syncDailyStats;
  late bool _syncProblems;
  late bool _includeProblemNote;
  late bool _includeProblemAnalysis;
  late bool _autoSyncAfterRefresh;

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
    _syncEndpointController = TextEditingController(
      text: widget.config.sync.endpointUrl,
    );
    _syncTokenController = TextEditingController(text: widget.initialSyncToken);
    _enabled = {
      for (final meta in supportedOjs)
        meta.id: widget.config.accounts[meta.id]?.enabled ?? false,
    };
    _launchAtStartup = widget.config.launchAtStartup;
    _alwaysOnTop = widget.config.alwaysOnTop;
    _showInTaskbar = widget.config.showInTaskbar;
    _closeToTray = widget.config.closeToTray;
    _colorTheme = widget.config.colorTheme;
    _compactClickTarget = widget.config.compactClickTarget;
    _dashboardModules = [...widget.config.dashboardModules];
    _syncEnabled = widget.config.sync.enabled;
    _syncDailyStats = widget.config.sync.syncDailyStats;
    _syncProblems = widget.config.sync.syncProblems;
    _includeProblemNote = widget.config.sync.includeProblemNote;
    _includeProblemAnalysis = widget.config.sync.includeProblemAnalysis;
    _autoSyncAfterRefresh = widget.config.sync.autoSyncAfterRefresh;
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _syncEndpointController.dispose();
    _syncTokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('设置'),
      content: SizedBox(
        width: 460,
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
                title: const Text('登录时启动'),
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
                title: const Text('关闭时隐藏到托盘'),
                value: _closeToTray,
                onChanged: (value) {
                  setState(() => _closeToTray = value);
                },
              ),
              DropdownButtonFormField<AppColorTheme>(
                key: const ValueKey('color-theme-field'),
                initialValue: _colorTheme,
                decoration: const InputDecoration(
                  labelText: '配色主题',
                  isDense: true,
                ),
                items: [
                  for (final theme in AppColorTheme.values)
                    DropdownMenuItem(
                      value: theme,
                      child: Text(_colorThemeLabel(theme)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _colorTheme = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<CompactClickTarget>(
                key: const ValueKey('compact-click-target-field'),
                initialValue: _compactClickTarget,
                decoration: const InputDecoration(
                  labelText: '小浮窗点击后进入',
                  isDense: true,
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
                    setState(() => _compactClickTarget = value);
                  }
                },
              ),
              const Divider(height: 24),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '大浮窗显示模块',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 6),
              for (final module in defaultDashboardModules)
                CheckboxListTile(
                  key: ValueKey('dashboard-module-enabled-${module.id}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(_dashboardModuleIcon(module), size: 20),
                  title: Text(_dashboardModuleLabel(module)),
                  value: _dashboardModules.contains(module),
                  onChanged: (value) => _setDashboardModuleEnabled(
                    module,
                    value ?? true,
                  ),
                ),
              if (_dashboardModules.isNotEmpty) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '显示顺序',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              for (final item in _dashboardModules.indexed)
                _DashboardModuleOrderTile(
                  key: ValueKey('dashboard-module-${item.$2.id}'),
                  module: item.$2,
                  isFirst: item.$1 == 0,
                  isLast: item.$1 == _dashboardModules.length - 1,
                  onMoveUp: () => _moveDashboardModule(item.$1, -1),
                  onMoveDown: () => _moveDashboardModule(item.$1, 1),
                ),
              if (_dashboardModules.isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '大浮窗暂不显示模块，只保留顶部操作。',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const Divider(height: 24),
              SwitchListTile(
                key: const ValueKey('sync-enabled-switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('网页钩子同步'),
                subtitle: const Text('默认关闭，只发送已选择的字段。'),
                value: _syncEnabled,
                onChanged: (value) {
                  setState(() => _syncEnabled = value);
                },
              ),
              TextField(
                key: const ValueKey('sync-endpoint-field'),
                controller: _syncEndpointController,
                decoration: const InputDecoration(
                  labelText: '同步地址',
                  hintText: 'https://example.com/api/oj-sync',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('sync-token-field'),
                controller: _syncTokenController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '同步密钥',
                  isDense: true,
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('每日日期和总通过数'),
                value: _syncDailyStats,
                onChanged: (value) {
                  setState(() => _syncDailyStats = value ?? true);
                },
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('题目标题、链接、平台、状态、标签'),
                value: _syncProblems,
                onChanged: (value) {
                  setState(() => _syncProblems = value ?? true);
                },
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('包含题目备注'),
                subtitle: const Text('敏感信息，默认关闭。'),
                value: _includeProblemNote,
                onChanged: (value) {
                  setState(() => _includeProblemNote = value ?? false);
                },
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('包含题解分析'),
                subtitle: const Text('高度敏感，默认关闭。'),
                value: _includeProblemAnalysis,
                onChanged: (value) {
                  setState(() => _includeProblemAnalysis = value ?? false);
                },
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('刷新后自动同步'),
                value: _autoSyncAfterRefresh,
                onChanged: (value) {
                  setState(() => _autoSyncAfterRefresh = value ?? true);
                },
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '不会发送 OJ 密码、Cookie、令牌、OJ 用户名或账号级增量。',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const Divider(height: 24),
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
        TextButton(
          onPressed: () {
            Navigator.pop(context, _buildResult(syncNow: true));
          },
          child: const Text('保存并立即同步'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, _buildResult());
          },
          child: const Text('保存'),
        ),
      ],
    );
  }

  void _moveDashboardModule(int index, int delta) {
    final nextIndex = index + delta;
    if (nextIndex < 0 || nextIndex >= _dashboardModules.length) {
      return;
    }
    setState(() {
      final modules = [..._dashboardModules];
      final module = modules.removeAt(index);
      modules.insert(nextIndex, module);
      _dashboardModules = modules;
    });
  }

  void _setDashboardModuleEnabled(DashboardModule module, bool enabled) {
    setState(() {
      final modules = [..._dashboardModules];
      if (enabled) {
        if (!modules.contains(module)) {
          modules.add(module);
        }
      } else {
        modules.remove(module);
      }
      _dashboardModules = modules;
    });
  }

  SettingsDialogResult _buildResult({bool syncNow = false}) {
    final accounts = {
      for (final meta in supportedOjs)
        meta.id: OjAccountConfig(
          usernames: OjAccountConfig.normalizeUsernames(
            [_controllers[meta.id]!.text],
          ),
          enabled: _enabled[meta.id] ?? false,
        ),
    };
    return SettingsDialogResult(
      config: AppConfig(
        refreshIntervalMinutes: _intervalMinutes.clamp(15, 1440).toInt(),
        accounts: accounts,
        dashboardModules: List.unmodifiable(_dashboardModules),
        colorTheme: _colorTheme,
        compactClickTarget: _compactClickTarget,
        launchAtStartup: _launchAtStartup,
        alwaysOnTop: _alwaysOnTop,
        showInTaskbar: _showInTaskbar,
        closeToTray: _closeToTray,
        sync: SyncConfig(
          enabled: _syncEnabled,
          endpointUrl: _syncEndpointController.text.trim(),
          syncDailyStats: _syncDailyStats,
          syncProblems: _syncProblems,
          includeProblemNote: _includeProblemNote,
          includeProblemAnalysis: _includeProblemAnalysis,
          autoSyncAfterRefresh: _autoSyncAfterRefresh,
        ),
      ),
      syncToken: _syncTokenController.text,
      syncNow: syncNow,
    );
  }
}

String _colorThemeLabel(AppColorTheme theme) {
  return switch (theme) {
    AppColorTheme.classic => '默认绿',
    AppColorTheme.ocean => '海风蓝',
    AppColorTheme.rose => '玫瑰粉',
    AppColorTheme.dark => '深色',
    AppColorTheme.candy => '彩蛋',
  };
}

class _DashboardModuleOrderTile extends StatelessWidget {
  const _DashboardModuleOrderTile({
    super.key,
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
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(_dashboardModuleIcon(module), size: 20),
      title: Text(_dashboardModuleLabel(module)),
      trailing: SizedBox(
        width: 96,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              key: ValueKey('dashboard-module-up-${module.id}'),
              tooltip: '上移',
              onPressed: isFirst ? null : onMoveUp,
              icon: const Icon(Icons.arrow_upward, size: 18),
            ),
            IconButton(
              key: ValueKey('dashboard-module-down-${module.id}'),
              tooltip: '下移',
              onPressed: isLast ? null : onMoveDown,
              icon: const Icon(Icons.arrow_downward, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

String _dashboardModuleLabel(DashboardModule module) {
  return switch (module) {
    DashboardModule.summary => '总览',
    DashboardModule.heatmap => '热力图',
    DashboardModule.problems => '题单',
    DashboardModule.refreshLogs => '刷新日志',
    DashboardModule.contests => '训练赛',
    DashboardModule.teammates => '队友',
    DashboardModule.ojAccounts => 'OJ 账号',
    DashboardModule.daily => '每日总结',
  };
}

IconData _dashboardModuleIcon(DashboardModule module) {
  return switch (module) {
    DashboardModule.summary => Icons.query_stats,
    DashboardModule.heatmap => Icons.calendar_view_week,
    DashboardModule.problems => Icons.bookmark_border,
    DashboardModule.refreshLogs => Icons.history,
    DashboardModule.contests => Icons.emoji_events_outlined,
    DashboardModule.teammates => Icons.groups_2_outlined,
    DashboardModule.ojAccounts => Icons.account_circle_outlined,
    DashboardModule.daily => Icons.today_outlined,
  };
}
