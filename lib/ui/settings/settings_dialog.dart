part of '../../main.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key, required this.config});

  final AppConfig config;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late int _intervalMinutes;
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, bool> _enabled;
  late bool _launchAtStartup;
  late bool _alwaysOnTop;
  late bool _showInTaskbar;
  late bool _closeToTray;

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
    _enabled = {
      for (final meta in supportedOjs)
        meta.id: widget.config.accounts[meta.id]?.enabled ?? false,
    };
    _launchAtStartup = widget.config.launchAtStartup;
    _alwaysOnTop = widget.config.alwaysOnTop;
    _showInTaskbar = widget.config.showInTaskbar;
    _closeToTray = widget.config.closeToTray;
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('设置'),
      content: SizedBox(
        width: 420,
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
                title: const Text('Start at login'),
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
                title: const Text('关闭时最小化到托盘'),
                value: _closeToTray,
                onChanged: (value) {
                  setState(() => _closeToTray = value);
                },
              ),
              const SizedBox(height: 10),
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
        FilledButton(
          onPressed: () {
            final accounts = {
              for (final meta in supportedOjs)
                meta.id: OjAccountConfig(
                  usernames: OjAccountConfig.normalizeUsernames(
                    [_controllers[meta.id]!.text],
                  ),
                  enabled: _enabled[meta.id] ?? false,
                ),
            };
            Navigator.pop(
              context,
              AppConfig(
                refreshIntervalMinutes:
                    _intervalMinutes.clamp(15, 1440).toInt(),
                accounts: accounts,
                launchAtStartup: _launchAtStartup,
                alwaysOnTop: _alwaysOnTop,
                showInTaskbar: _showInTaskbar,
                closeToTray: _closeToTray,
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
