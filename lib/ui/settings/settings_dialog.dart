import 'package:flutter/material.dart';

import '../../core/oj_catalog.dart';
import '../../models/app_config.dart';
import '../app_theme.dart';

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
      titlePadding:
          const EdgeInsets.fromLTRB(appSpace5, appSpace5, appSpace5, 0),
      contentPadding:
          const EdgeInsets.fromLTRB(appSpace5, appSpace3, appSpace5, appSpace3),
      actionsPadding:
          const EdgeInsets.fromLTRB(appSpace4, 0, appSpace4, appSpace4),
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(appRadiusControl),
              border: Border.all(color: accentColor.withValues(alpha: 0.2)),
            ),
            child: Icon(Icons.tune, color: accentColor),
          ),
          const SizedBox(width: appSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '设置',
                  style: TextStyle(
                    color: textPrimaryColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '账号、窗口和同步',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: textSecondaryColor, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
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
              const SizedBox(height: appSpace4),
              const _SettingsSectionHeader(
                icon: Icons.sync_outlined,
                title: '网页钩子同步',
                subtitle: '默认关闭，只发送已选择的公开字段',
              ),
              const SizedBox(height: appSpace2),
              SwitchListTile(
                key: const ValueKey('sync-enabled-switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('启用网页钩子同步'),
                subtitle: const Text('保存后按同步配置发送公开投影。'),
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
              const SizedBox(height: appSpace4),
              const _SettingsSectionHeader(
                icon: Icons.account_circle_outlined,
                title: 'OJ 账号',
                subtitle: '启用需要统计的平台，并填写公开用户名或 ID',
              ),
              const SizedBox(height: appSpace2),
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

class _SettingsSectionHeader extends StatelessWidget {
  const _SettingsSectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(appSpace3),
      decoration: BoxDecoration(
        color: cardMutedColor,
        borderRadius: BorderRadius.circular(appRadiusControl),
        border: Border.all(color: borderColor),
      ),
      child: Row(
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
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: textSecondaryColor, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
