# OJ Float 展示素材复现手册（T03-A）

本文档说明如何在本机重新生成 README 的截图（`docs/images/overview.png`、
`docs/images/problems.png`、`docs/images/training.png`）和操作演示
（`docs/images/demo.gif`）。全部素材使用可复现的本地演示数据，不依赖网络、不
包含真实账号 / 笔记 / 令牌 / 本机用户名。

## 1. 前置条件

- Windows 10 / 11 x64，有可交互桌面。
- Flutter（本任务验证环境为 Flutter 3.44.2，Windows 桌面支持已启用）。
- Visual Studio 2022/2026 + “使用 C++ 的桌面开发”工作负载。
- ffmpeg（用于把 PNG 帧合成 GIF）：

  ```powershell
  winget install Gyan.FFmpeg --scope user
  ```

- PowerShell 5.1（Windows 自带）。脚本文件已带 UTF-8 BOM，直接用即可。

## 2. 构建可运行版本

```powershell
flutter pub get
flutter build windows --release
```

构建产物为 `build\windows\x64\runner\Release\oj_float.exe`。如果本机 MSBuild
HostX86 卡住，改用仓库的 Ninja 脚本：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build_windows_release_ninja.ps1
```

（Ninja 产物在 `build\windows\ninja\runner\oj_float.exe`，此时需把后续命令的
`-ExePath` 指到该路径。）

## 3. 隔离本机真实数据目录（重要）

截图前必须先移开真实数据，避免把真实账号 / 笔记 / 令牌拍进截图。应用的数据
目录由 `lib/services/app_data_directory.dart` 解析到：

- 当前目录：`%APPDATA%\ZuesHans\OJ Float`
- 旧版目录：`%APPDATA%\com.example\oj_float`

两者都要移开（否则首次启动会自动把旧目录迁移进来）：

```powershell
Rename-Item "$env:APPDATA\ZuesHans\OJ Float" "OJ Float.real-showcase-backup" -ErrorAction SilentlyContinue
Rename-Item "$env:APPDATA\com.example\oj_float" "oj_float.real-showcase-backup" -ErrorAction SilentlyContinue
```

完成后重新生成素材，最后用第 7 节的命令原样恢复。

## 4. 写入可复现演示数据

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\showcase\seed_demo_data.ps1 `
  -ExePath "C:\path\to\build\windows\x64\runner\Release\oj_float.exe"
```

脚本离线、确定性生成（当天日期作为锚点，可用 `-Today 2026-10-24` 固定）：

- 假账号：`DemoCoder`（Codeforces）、`demo_learner`（LeetCode）。
- 约 292 条通过数快照，驱动首页热力图、连续记录与“今日 +N”。
- 12 道题（待安排 / 训练中 / 已掌握 / 已归档）写入 `problems_v1.json`，再通过
  `--migrate-problem-database-and-exit` 由应用自身迁移进 `problem_book.sqlite3`。
- 训练题单、6 条训练记录、今日待办、2 条比赛记录、刷新日志。
- 关闭“OJ 账号”模块，使 `refresh()` 为空操作，抓取过程完全离线、确定性。

> 说明：当前版本首页“累计通过”只由实时刷新结果派生（`state.latest`），离线
> 演示数据无法填充它，因此截图里该数字为 0；热力图、连续记录、今日增量、训练
> 安排、题库、比赛等均由快照/文件派生，能正常展示。这是可运行版本的真实行为，
> 不为了截图而修改 `lib/`。

## 5. 拍摄三张截图

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\showcase\capture_screenshots.ps1
```

脚本对每个页面写入 `window_state.json`（section = summary / problems / training），
启动 release 客户端，用 Win32 `GetWindowRect` + `Graphics.CopyFromScreen` 抓取
含原生标题栏的整窗区域，保存到 `docs/images/`。

## 6. 录制浏览器存题演示

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden `
  -File scripts\showcase\record_demo.ps1
```

流程：启动客户端并切到题库页 → 打开本地 mock 题目页
（`scripts/showcase/mock_problem.html`，Edge `--app` 模式）→ 并排两窗 → 逐帧抓取
约 12 秒 → 在第 2.5 秒由 `import_problem.ps1`（等价于浏览器扩展的一键存题）向
`127.0.0.1:27121/v1/problems/import` POST 一道假题 → 客户端 1 秒轮询后出现该题 →
`frame_to_gif.ps1` 用 ffmpeg 合成 `docs/images/demo.gif`（5 fps，宽度 ≤ 1100px）。

> 该演示是脚本驱动的，不是真实浏览器扩展；README 中已明确标注。

## 7. 恢复本机真实数据目录

```powershell
Remove-Item "$env:APPDATA\ZuesHans\OJ Float" -Recurse -Force -ErrorAction SilentlyContinue
Rename-Item "$env:APPDATA\ZuesHans\OJ Float.real-showcase-backup" "OJ Float" -ErrorAction SilentlyContinue
Remove-Item "$env:APPDATA\com.example\oj_float" -Recurse -Force -ErrorAction SilentlyContinue
Rename-Item "$env:APPDATA\com.example\oj_float.real-showcase-backup" "oj_float" -ErrorAction SilentlyContinue
```

确认 `oj_float.exe`、`msedge.exe`（演示用）均已关闭，不要留下运行中的客户端。

## 8. 隐私自检

- 用 OCR 或肉眼核对四张图，确认只有假账号与 mock 题目，无真实用户名 / 笔记 /
  令牌 / 路径。
- `git grep -n` 检查 `scripts/showcase/`，确认没有本机用户名、真实账号或令牌（把下面命令中的 `<your-username>` 换成你本机的用户名）：

  ```powershell
  git grep -nE "<your-username>|Bearer [A-Za-z0-9_-]{8,}" -- scripts/showcase
  ```

  （`DemoCoder` / `demo_learner` 是刻意使用的假账号；脚本里出现的 `oj_float_browser_import_token_v1` 只是安全存储的键名，`Bearer $token` 是运行时读取令牌的代码，不含真实令牌。）

## 9. 环境备注

- 本任务验证机的显示器缩放为 150%（物理 2560x1600）。截图按应用默认窗口尺寸
  1120×760 逻辑像素拍摄，因此 PNG 物理尺寸为 1680×1140，文字在 150% 下清晰可读。
- 演示 GIF 由 ffmpeg 二阶段调色板（`palettegen` + `paletteuse`）压缩，约 256 KB。
