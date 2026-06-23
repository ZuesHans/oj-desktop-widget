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
      title: const Text('Settings'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('Auto refresh interval')),
                  SizedBox(
                    width: 110,
                    child: TextFormField(
                      initialValue: '$_intervalMinutes',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(suffixText: 'min'),
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
                title: const Text('Always on top'),
                value: _alwaysOnTop,
                onChanged: (value) {
                  setState(() => _alwaysOnTop = value);
                },
              ),
              SwitchListTile(
                key: const ValueKey('show-in-taskbar-switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Show in taskbar'),
                value: _showInTaskbar,
                onChanged: (value) {
                  setState(() => _showInTaskbar = value);
                },
              ),
              SwitchListTile(
                key: const ValueKey('close-to-tray-switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Close to tray'),
                value: _closeToTray,
                onChanged: (value) {
                  setState(() => _closeToTray = value);
                },
              ),
              const Divider(height: 24),
              SwitchListTile(
                key: const ValueKey('sync-enabled-switch'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Webhook sync'),
                subtitle:
                    const Text('Off by default. Sends only selected fields.'),
                value: _syncEnabled,
                onChanged: (value) {
                  setState(() => _syncEnabled = value);
                },
              ),
              TextField(
                key: const ValueKey('sync-endpoint-field'),
                controller: _syncEndpointController,
                decoration: const InputDecoration(
                  labelText: 'Sync endpoint URL',
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
                  labelText: 'Sync token',
                  isDense: true,
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Daily date + total solved'),
                value: _syncDailyStats,
                onChanged: (value) {
                  setState(() => _syncDailyStats = value ?? true);
                },
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Problem title, URL, platform, status, tags'),
                value: _syncProblems,
                onChanged: (value) {
                  setState(() => _syncProblems = value ?? true);
                },
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Include problem notes'),
                subtitle: const Text('Sensitive. Off by default.'),
                value: _includeProblemNote,
                onChanged: (value) {
                  setState(() => _includeProblemNote = value ?? false);
                },
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Include solution analysis'),
                subtitle: const Text('Highly sensitive. Off by default.'),
                value: _includeProblemAnalysis,
                onChanged: (value) {
                  setState(() => _includeProblemAnalysis = value ?? false);
                },
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto sync after refresh'),
                value: _autoSyncAfterRefresh,
                onChanged: (value) {
                  setState(() => _autoSyncAfterRefresh = value ?? true);
                },
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Never sends OJ passwords, cookies, tokens, OJ usernames, '
                  'or account-level deltas.',
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
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context, _buildResult(syncNow: true));
          },
          child: const Text('Save & Sync Now'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, _buildResult());
          },
          child: const Text('Save'),
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
