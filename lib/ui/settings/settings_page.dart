import 'package:flutter/material.dart';

import '../../core/oj_catalog.dart';
import '../../models/app_config.dart';
import '../app_theme.dart';
import '../shared/app_surface_card.dart';

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
    this.browserImportToken = '',
    this.browserImportRunning = false,
    this.browserImportPort = 27121,
    this.browserImportError = '',
    this.onRotateBrowserImportToken,
  });

  final AppConfig config;
  final String initialSyncToken;
  final Future<void> Function(SettingsPageResult result) onSave;
  final String browserImportToken;
  final bool browserImportRunning;
  final int browserImportPort;
  final String browserImportError;
  final Future<void> Function()? onRotateBrowserImportToken;

  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _intervalController;
  late final TextEditingController _syncEndpointController;
  late final TextEditingController _syncTokenController;
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

  bool _dirty = false;
  bool _saving = false;

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
  }

  @override
  void dispose() {
    _intervalController.dispose();
    _syncEndpointController.dispose();
    _syncTokenController.dispose();
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
      _dirty = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('dashboard-section-settings'),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
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
                  icon: Icons.schedule_outlined,
                  title: '常规',
                  subtitle: '控制自动刷新频率和客户端后台行为',
                  child: Column(
                    children: [
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
                _SettingsSection(
                  icon: Icons.extension_outlined,
                  title: '浏览器导入',
                  subtitle: 'Edge / Chrome 扩展只发送当前题目的公开页面信息',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                          fontWeight: FontWeight.w700,
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
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(appRadiusControl),
          ),
          child: Icon(Icons.tune, color: accentColor, size: 21),
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
              Text(
                _dirty ? '有未保存的更改' : '配置客户端、同步和 OJ 账号',
                style: TextStyle(
                  color: _dirty ? accentColor : textSecondaryColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

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

    final accounts = {
      for (final meta in supportedOjs)
        meta.id: OjAccountConfig(
          usernames: OjAccountConfig.normalizeUsernames(
            [_accountControllers[meta.id]!.text],
          ),
          enabled: _accountEnabled[meta.id] ?? false,
        ),
    };
    final config = widget.config.copyWith(
      refreshIntervalMinutes: interval,
      accounts: accounts,
      closeToTray: _closeToTray,
      launchAtStartup: _closeToTray && _launchAtStartup,
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
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(syncNow ? '设置已保存并完成同步。' : '设置已保存。')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存设置失败：$error')),
      );
    }
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
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
      padding: const EdgeInsets.all(appSpace4),
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
                        fontWeight: FontWeight.w900,
                      ),
                    ),
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
