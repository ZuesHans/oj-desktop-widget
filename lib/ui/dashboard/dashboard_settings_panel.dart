import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/app_config.dart';
import '../app_theme.dart';
import '../shared/app_surface_card.dart';
import 'dashboard_navigation.dart';

class DashboardSettingsPanel extends StatelessWidget {
  const DashboardSettingsPanel({
    super.key,
    required this.config,
    required this.onSaveConfig,
    required this.onOpenFullSettings,
  });

  final AppConfig config;
  final Future<void> Function(AppConfig config) onSaveConfig;
  final VoidCallback onOpenFullSettings;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('dashboard-section-settings'),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      children: [
        const DashboardSectionTitle(
          section: DashboardSection.settings,
          subtitle: '常用窗口选项放在这里，完整账号和同步配置仍在设置对话框里。',
        ),
        const SizedBox(height: 14),
        AppSurfaceCard(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            children: [
              _SettingSwitch(
                title: '登录时启动',
                subtitle: '开机后自动启动 OJ Float',
                value: config.launchAtStartup,
                onChanged: (value) => unawaited(
                  onSaveConfig(config.copyWith(launchAtStartup: value)),
                ),
              ),
              _SettingSwitch(
                title: '窗口置顶',
                subtitle: '让悬浮窗保持在其他窗口上方',
                value: config.alwaysOnTop,
                onChanged: (value) => unawaited(
                  onSaveConfig(config.copyWith(alwaysOnTop: value)),
                ),
              ),
              _SettingSwitch(
                title: '在任务栏显示',
                subtitle: '关闭后仍可从托盘菜单找回',
                value: config.showInTaskbar,
                onChanged: (value) => unawaited(
                  onSaveConfig(config.copyWith(showInTaskbar: value)),
                ),
              ),
              _SettingSwitch(
                title: '关闭时隐藏到托盘',
                subtitle: '点击关闭按钮时后台保留状态',
                value: config.closeToTray,
                onChanged: (value) => unawaited(
                  onSaveConfig(config.copyWith(closeToTray: value)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey('dashboard-open-full-settings-button'),
                  onPressed: onOpenFullSettings,
                  icon: const Icon(Icons.tune),
                  label: const Text('打开完整设置'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: TextStyle(
          color: textPrimaryColor,
          fontWeight: FontWeight.w800,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: textSecondaryColor, fontSize: 12),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}
