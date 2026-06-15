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
