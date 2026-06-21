# OJ Float

OJ Float 是一个 Windows 桌面悬浮 OJ 做题统计工具，用来集中查看多个 Online Judge 账号的通过题数变化。

当前版本为测试版

## 下载测试版

请在 GitHub Releases 中下载最新的 Windows 测试包：

```text
OJ-Float-v0.1.1-beta.2-windows-x64.zip
```

使用方式：

1. 下载 zip 文件。
2. 解压到任意文件夹。
3. 运行解压后的 `oj_float.exe`。

注意：不要只复制或单独运行 `oj_float.exe`。应用需要同目录下的 `data` 文件夹和运行库文件。

## 功能

- 支持 Codeforces、LeetCode、AtCoder、洛谷、牛客。
- 每 1 小时自动刷新一次通过题数可自定义刷新时间
- 支持手动刷新。
- 单个 OJ 抓取失败不会影响其他 OJ。
- 本地保存刷新快照。
- 按“当天最后快照 - 当天首次快照”生成每日总结。
- 支持热力图、连续记录和汇总查看。
- 支持补题 / 错题本记录题目链接，并可点击“前往题目”用默认浏览器打开原题。
- 支持小型置顶悬浮窗。
- 支持系统托盘菜单。
- 支持开机启动设置。
- 支持数据备份导出和导入。

## 使用说明

首次打开后进入设置，填写各 OJ 的用户名或用户 ID。

- Codeforces：填写公开 handle。
- LeetCode：填写公开 username。
- AtCoder：填写公开 username。
- 洛谷：建议填写数字 UID。
- 牛客：建议填写数字用户 ID。

保存后可以手动刷新，也可以等待应用自动刷新。

## 数据与隐私

- 数据只保存在本机应用目录。
- 应用不会上传你的配置、统计数据或备份文件。
- 备份文件不包含密码、Cookie 或 Token。
- 抓取结果依赖各 OJ 的公开页面或公开接口。
- 如果账号不存在、账号不可公开访问、网络异常或 OJ 页面结构变化，部分平台可能刷新失败。

## 备份与迁移

跨设备迁移时，请使用应用内的备份 JSON。

1. 在旧电脑打开 OJ Float。
2. 点击 **Export Backup** 导出备份。
3. 将生成的 `oj_float_backup_YYYYMMDD_HHMM.json` 复制到新电脑。
4. 在新电脑打开 OJ Float。
5. 点击 **Import Backup**。
6. 选择复制过来的备份 JSON。
7. 应用会用备份中的配置和快照替换当前本地数据。

导入前，应用会自动创建一份安全备份：

```text
oj_float_pre_import_backup_YYYYMMDD_HHMM.json
```

说明：

- `dailyStats` 和热力图是派生数据。
- 导入时会使用 `config` 和 `snapshots` 重新计算每日统计、热力图和连续记录。
- CSV 导出只用于查看或表格分析，不能用于恢复。

## 预计更新

- 更多oj平台的支持:如马蹄，蓝桥
- 可能加入深色模式
- 加入折线热力图
- 加入计划表
- 加入网络赛提醒，rating折线图
- ui优化


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

分发测试包时，请压缩整个 `Release` 文件夹。

## 关于这个

整个项目几乎是vibecoding出来的结果，但是feat 和 修改都是自己全程盯着做的。

## 版权与测试版说明

Developer: zueshans

Copyright © 2026 zueshans. All rights reserved.

当前版本为测试版，仅供测试和反馈使用。未经开发者许可，不得重新分发、修改、售卖、发布或重新打包本软件。
