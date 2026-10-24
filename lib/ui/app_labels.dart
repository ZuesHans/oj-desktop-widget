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
  static const importConfirmMessage = '请选择 OJ Float 生成的 JSON 备份。\n\n'
      '完整便携备份会替换本地配置、抓取快照、题目、训练、题单、日程、比赛和队友数据，并清空刷新日志。\n\n'
      '核心自动备份只会替换题目、训练记录、复盘、题单、日程、未结束计时任务和比赛记录；OJ 配置、抓取快照、队友数据和刷新日志保持不变。\n\n'
      '实际写入前会额外生成一份不参与轮换的安全备份。';
  static const portableImportSuccessPrefix =
      '完整便携备份导入完成。配置、抓取快照、题目、训练、题单、日程、比赛和队友数据已替换，刷新日志已清空。安全备份：';
  static const coreTrainingImportSuccessPrefix =
      '核心训练备份导入完成。题目、训练记录、复盘、题单、日程、未结束计时任务和比赛记录已替换；OJ 配置和抓取数据保持不变。安全备份：';
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
