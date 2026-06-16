# OJ Float

Windows 桌面悬浮 OJ 做题统计插件。

## 功能

- 每 1 小时自动刷新一次各 OJ 通过题数，也可以手动刷新。
- 支持 Codeforces、LeetCode、AtCoder、洛谷、牛客。
- 单个 OJ 抓取失败不会影响其他 OJ。
- 本地保存刷新快照，并按“当天最后快照 - 当天首次快照”生成每日总结。
- Windows 上支持小型置顶悬浮窗和系统托盘。

## 本地运行

当前目录只包含应用源码。如果还没有 Flutter Windows 工程壳，请先安装 Flutter，并在本目录执行：

```powershell
flutter create --platforms=windows .
flutter pub get
flutter run -d windows
```

## 使用说明

首次打开后进入设置，填写各 OJ 的用户名或用户 ID。

- Codeforces、LeetCode、AtCoder：填写公开用户名。
- 洛谷：建议填写数字 UID。
- 牛客：建议填写数字用户 ID。

数据只保存在本地应用目录，不会上传。
## Cross-device backup and restore

Use the portable backup JSON when moving OJ Float data to another device.

1. On the old computer, open the dashboard and click **Export Backup**.
2. Copy the generated `oj_float_backup_YYYYMMDD_HHMM.json` file to the new computer.
3. Install or open OJ Float on the new computer.
4. Click **Import Backup**.
5. Select the copied backup JSON file.
6. The app will replace the current local config and snapshots with the data from the backup.
7. `dailyStats` and the heatmap are derived data. Restore uses `config` and `snapshots`, then recalculates daily stats, heatmap, and streaks.
8. Before import, the app automatically creates a safety backup named `oj_float_pre_import_backup_YYYYMMDD_HHMM.json`.
9. CSV exports are only for viewing or spreadsheet analysis. CSV files are not used for restore.
