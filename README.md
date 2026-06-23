# OJ Float

OJ Float 是一个 Windows 桌面悬浮 OJ 刷题统计工具，用来集中查看多个 Online Judge 账号的通过题数变化、补题记录和训练记录。

当前稳定版：`v0.1.3`

## 下载

请在 GitHub Releases 下载最新版 Windows x64 稳定包：

```text
OJ-Float-v0.1.3-windows-x64.zip
```

使用方式：

1. 下载 zip 文件。
2. 解压到任意文件夹。
3. 运行解压后的 `oj_float.exe`。

注意：不要只复制或单独运行 `oj_float.exe`。应用需要同目录下的 `data` 文件夹和运行库 DLL。

## 功能

- 支持 Codeforces、LeetCode、AtCoder、洛谷、牛客。
- 支持多个账号统计和手动/自动刷新。
- 本地保存刷新快照，并按“当天最后快照 - 当天首次快照”生成每日总结。
- 支持热力图、连续记录和汇总查看。
- 支持补题 / 错题本，记录题目链接、标签、备注和题解分析。
- 支持自定义训练赛记录和排名曲线。
- 支持队友观察，按训练日统计最近刷题增量。
- 支持小型置顶悬浮窗、系统托盘菜单、开机启动设置。
- 支持数据备份导出和导入。
- 支持可选的自定义 Webhook 同步，用于把公开投影数据同步到个人网站。

## v0.1.3 更新

- 新增 OJ Float Sync Webhook v1，可把每日总增量和题单公开字段同步到个人站点。
- 同步默认关闭，Token 使用系统安全存储，不写入普通配置 JSON。
- 默认同步不包含 OJ 用户名、账号级增量、密码、Cookie、Token、题目备注或题解分析。
- 备注和题解分析需要单独开启后才会进入同步 payload。
- 关闭某类同步时会发送空数组，便于服务端清空对应公开投影。
- 同步端点要求 HTTPS，只有 localhost HTTP 用于本地开发。
- 增强保存设置后的手动同步与自动同步流程。

## 使用说明

首次打开后进入设置，填写各 OJ 的用户名或用户 ID。

- Codeforces：填写公开 handle。
- LeetCode：填写公开 username。
- AtCoder：填写公开 username。
- 洛谷：建议填写数字 UID。
- 牛客：建议填写数字用户 ID。

保存后可以手动刷新，也可以等待应用按设定间隔自动刷新。

## Webhook 同步

在设置中开启 Webhook sync 后，填写：

- Sync endpoint URL：例如 `https://example.com/api/oj-sync`
- Sync token：服务端配置的 Bearer Token

同步 payload 只用于公开投影展示。默认字段包括：

- 每日日期和总刷题增量。
- 题目标题、链接、平台、状态、标签和更新时间。

可选敏感字段：

- 题目备注。
- 题解分析。

如果需要同步到 `keronshans-blog-next`，请在网站端配置 `OJ_SYNC_TOKEN`，部署包含 `/api/oj-sync` 和 `/api/oj-public/*` 的版本，并在 Cloudflare D1 应用最新 `schema.sql`。

## 数据与隐私

- 默认所有数据只保存在本机应用目录。
- 应用不会上传密码、Cookie 或 OJ Token。
- 备份文件不包含同步 Token。
- Webhook 同步为可选功能，默认关闭。
- Webhook 默认不发送 OJ 用户名和账号级增量。
- 抓取结果依赖各 OJ 的公开页面或公开接口。账号不存在、账号不可公开访问、网络异常或 OJ 页面结构变化时，部分平台可能刷新失败。

## 备份与迁移

跨设备迁移时，请使用应用内的备份 JSON。

1. 在旧电脑打开 OJ Float。
2. 点击 **Export Backup** 导出备份。
3. 将生成的 `oj_float_backup_YYYYMMDD_HHMM.json` 复制到新电脑。
4. 在新电脑打开 OJ Float。
5. 点击 **Import Backup**。
6. 选择复制过来的备份 JSON。
7. 应用会用备份中的配置、快照、题单、训练赛和队友数据替换当前本地数据。

导入前，应用会自动创建一份安全备份：

```text
oj_float_pre_import_backup_YYYYMMDD_HHMM.json
```

说明：

- `dailyStats` 和热力图是派生数据。
- 导入时会使用 `config` 和 `snapshots` 重新计算每日统计、热力图和连续记录。
- CSV 导出只用于查看或表格分析，不能用于恢复。

## 本地开发

需要先安装 Flutter，并启用 Windows 桌面支持。

```powershell
flutter config --enable-windows-desktop
flutter pub get
flutter run -d windows
```

发布前建议执行：

```powershell
flutter pub get
flutter analyze
flutter test
flutter build windows --release
```

Windows Release 构建产物位于：

```text
build\windows\x64\runner\Release
```

分发包需要压缩整个 `Release` 文件夹，而不是只分发 exe。

## 后续计划

- 支持更多 OJ 平台。
- 继续优化 UI 和深色主题体验。
- 增加更多训练数据图表。
- 增加网络赛提醒和 rating 趋势展示。

## 版权

Developer: zueshans

Copyright (C) 2026 zueshans. All rights reserved.

未经开发者许可，不得重新分发、修改、售卖、发布或重新打包本软件。
