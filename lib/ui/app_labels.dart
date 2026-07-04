import 'package:flutter/material.dart';

import '../app/app_display_mode.dart';
import '../models/app_config.dart';
import '../services/sync_service.dart';

class AppLabels {
  const AppLabels._();

  static const appTitle = 'OJ 悬浮窗';

  static const trayShowWindow = '显示窗口';
  static const trayHideWindow = '隐藏窗口';
  static const trayToggleOnTop = '窗口置顶/取消置顶';
  static const trayRefreshNow = '立即刷新';
  static const trayExit = '退出程序';

  static const dashboard = 'Dashboard';
  static const openDashboard = '进入 Dashboard';
  static const settingsSaveFailed = '设置保存失败';
  static const startupSettingsUpdateFailed = '登录时启动设置更新失败';

  static const exportSuccessPrefix = '已导出便携备份 JSON 和每日汇总 CSV 到';
  static const exportFailed = '导出失败';

  static const importBackup = '导入备份';
  static const importConfirmMessage = '导入会替换当前本地配置、快照、题单、比赛记录和队友数据。'
      '刷新日志只是本地诊断信息，导入后会清空。'
      '导入前会先创建一份安全备份。';
  static const importSuccessPrefix = '导入完成。本地配置、快照、题单、比赛记录和队友数据已用备份替换。'
      '刷新日志不属于便携备份，已清空。安全备份：';
  static const importFailed = '导入失败';

  static const invalidProblemUrl = '题目链接无效。';
  static const openProblemFailed = '无法打开题目链接。';

  static String modeLabel(AppDisplayMode mode) {
    return switch (mode) {
      AppDisplayMode.compact => '小浮窗',
      AppDisplayMode.largeFloat => '大浮窗',
      AppDisplayMode.dashboard => 'Dashboard',
      AppDisplayMode.heatmap => '热力图',
      AppDisplayMode.problems => '补题',
      AppDisplayMode.refreshLogs => '刷新日志',
      AppDisplayMode.contests => '训练赛',
      AppDisplayMode.teammates => '队友',
    };
  }

  static String dashboardModuleLabel(DashboardModule module) {
    return switch (module) {
      DashboardModule.summary => '总览',
      DashboardModule.heatmap => '热力图',
      DashboardModule.problems => '补题',
      DashboardModule.refreshLogs => '刷新日志',
      DashboardModule.contests => '训练赛',
      DashboardModule.teammates => '队友',
      DashboardModule.ojAccounts => 'OJ 账号',
      DashboardModule.daily => '每日总结',
    };
  }

  static String colorThemeLabel(AppColorTheme theme) {
    return switch (theme) {
      AppColorTheme.classic => '默认绿',
      AppColorTheme.ocean => '海风蓝',
      AppColorTheme.rose => '玫瑰粉',
      AppColorTheme.dark => '深色',
      AppColorTheme.candy => '彩蛋',
    };
  }

  static String syncResultMessage(SyncResult result) {
    switch (result.status) {
      case SyncStatus.success:
        return '同步成功：${result.endpointLabel}';
      case SyncStatus.skipped:
        return '已跳过同步：${result.message}';
      case SyncStatus.failure:
        final target =
            result.endpointLabel.isEmpty ? '目标地址' : result.endpointLabel;
        return '$target 同步失败：${result.message}';
    }
  }
}

IconData dashboardModuleIcon(DashboardModule module) {
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
