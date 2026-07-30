import '../services/sync_service.dart';

class AppLabels {
  const AppLabels._();

  static const appTitle = 'OJ Float';

  static const trayShowWindow = '显示窗口';
  static const trayRefreshNow = '立即刷新';
  static const trayExit = '退出程序';

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
