# OJ Float

OJ Float 是一个 Windows 桌面悬浮训练面板，用来集中查看多个 Online Judge 账号的刷题进度、今日增量、补题记录、比赛记录、队友观察和刷新日志。

当前预发行版本：`v0.1.3beta`

## 下载

请在 GitHub Releases 下载最新 Windows x64 免安装包：

```text
oj-desktop-widget-v0.1.3beta-windows-x64.zip
```

使用方式：

1. 下载 zip 文件。
2. 解压到任意文件夹。
3. 运行解压后的 `oj_float.exe`。

不要只复制或单独运行 `oj_float.exe`。应用需要同目录下的 `data` 文件夹和运行库 DLL。

## 这一版有什么变化

`v0.1.3beta` 是一次偏产品化的前端大修：

- 小窗、浮窗和 Dashboard 的职责重新划分：小窗只保留总通过数、今日增量和高频按钮；大浮窗用于快速查看状态；Dashboard 承担完整管理工作台。
- Dashboard 新增左侧导航和总览页，集中展示今日训练、账号状态、热力图入口、题单、比赛、队友、日志和设置。
- 统一卡片、按钮、标签、颜色主题和窗口标题栏，减少“拼起来的 demo 感”。
- 补题、比赛、队友、刷新日志、热力图等页面做了密度和视觉节奏优化。
- 小窗修复了固定窗口高度下的 RenderFlex overflow 黄黑条问题。
- 牛客刷新增强了兜底逻辑：OJ Hunt 失败后会尝试把昵称解析为牛客数字用户 ID；解析不到时会提示使用个人主页里的数字 ID。
- 新增 Windows Ninja release 构建脚本，绕过部分 Visual Studio 2026 / MSBuild HostX86 环境下的构建卡死问题。

## 功能

- 支持 Codeforces、LeetCode、AtCoder、洛谷、牛客。
- 支持多个账号统计、手动刷新和自动刷新。
- 支持每日增量、连续记录、热力图和刷新日志。
- 支持补题 / 错题本，记录题目链接、平台、状态、标签、备注和题解分析。
- 支持训练赛记录、排名曲线和复盘信息。
- 支持队友观察，按训练日统计近期刷题增量。
- 支持小型置顶悬浮窗、系统托盘、开机启动、关闭到托盘。
- 支持数据备份导出和导入。
- 支持可选 Webhook 同步，用于把公开训练投影同步到个人网站。

## 首次使用

首次打开后进入 Dashboard 的账号设置，填写各 OJ 的公开用户名或用户 ID。

- Codeforces：填写公开 handle。
- LeetCode：填写公开 username。
- AtCoder：填写公开 username。
- 洛谷：建议填写数字 UID。
- 牛客：优先填写个人主页里的数字用户 ID。昵称依赖第三方 OJ Hunt 或牛客搜索解析，稳定性不如数字 ID。

保存后可以手动刷新，也可以等待应用按设定间隔自动刷新。

## 数据与隐私

- 默认所有数据只保存在本机应用目录。
- 应用不会上传密码、Cookie 或 OJ Token。
- 备份文件不包含同步令牌（Token）。
- Webhook 同步是可选功能，默认关闭。
- Webhook 默认不发送 OJ 用户名和账号级增量。
- 备注和题解分析需要单独开启后才会进入同步 payload。
- 抓取结果依赖各 OJ 的公开页面或公开接口。账号不存在、账号不公开、网络异常或页面结构变化时，部分平台可能刷新失败。

## Webhook 同步

在设置中开启 Webhook sync 后填写：

- Sync endpoint URL，例如 `https://example.com/api/oj-sync`
- Sync token，服务端配置的 Bearer 令牌（Token）

同步 payload 只用于公开展示。默认字段包括每日日期、总刷题增量、题目标题、链接、平台、状态、标签和更新时间。

可选敏感字段包括：

- 题目备注
- 题解分析

同步站点要求 HTTPS；只有 `localhost` HTTP 允许用于本地开发。

## 备份与迁移

跨设备迁移时，请使用应用内的备份 JSON。

1. 在旧电脑打开 OJ Float。
2. 点击 Export Backup 导出备份。
3. 将生成的 `oj_float_backup_YYYYMMDD_HHMM.json` 复制到新电脑。
4. 在新电脑打开 OJ Float。
5. 点击 Import Backup（导入备份）。
6. 选择复制过来的备份 JSON。
7. 应用会用备份中的配置、快照、题单、训练赛和队友数据替换当前本地数据。

导入前，应用会自动创建一份安全备份：

```text
oj_float_pre_import_backup_YYYYMMDD_HHMM.json
```

说明：

- `dailyStats` 和热力图是派生数据。
- 导入时会使用 `config` 和 `snapshots` 重新计算每日统计、热力图和连续记录。
- CSV 导出只适合查看或表格分析，不能用于恢复。

## 本地开发

需要先安装 Flutter，并启用 Windows 桌面支持。

```powershell
flutter config --enable-windows-desktop
flutter pub get
flutter run -d windows
```

常规检查：

```powershell
dart analyze lib test
flutter test
```

如果本机 `flutter build windows --release` 因 Visual Studio / MSBuild HostX86 工具链卡住或失败，可以使用仓库里的 Ninja 构建脚本：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build_windows_release_ninja.ps1
```

构建产物位于：

```text
build\windows\ninja\runner
```

分发时需要压缩整个 `runner` 文件夹，而不是只分发 exe。

## 发行检查

发布前建议执行：

```powershell
dart analyze lib test
flutter test
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build_windows_release_ninja.ps1
```

确认 zip 内至少包含：

- `oj_float.exe`
- `flutter_windows.dll`
- `data\app.so`
- `data\flutter_assets`
- 插件 DLL，例如 `window_manager_plugin.dll`、`tray_manager_plugin.dll`

## 后续计划

- 把题单、比赛、队友页面继续拆成更小的组件。
- 增加 rating 趋势和比赛提醒。
- 增加更完整的发行脚本，包括自动打包、校验和 release notes 生成。
- 继续优化首次启动、空状态、错误状态和网络异常提示。

## 版权

Developer: zueshans

Copyright (C) 2026 zueshans. All rights reserved.

未经开发者许可，不得重新分发、修改、售卖、发布或重新打包本软件。
