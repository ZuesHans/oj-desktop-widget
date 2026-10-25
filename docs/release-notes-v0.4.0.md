# OJ Float v0.4.0 发布说明

发布日期：2026-10-25

本版本发布已批准的 Workbench 工作台界面重构。它把 OJ Float 的默认视觉收敛为一套安静、耐用的深色绿系桌面界面，同时保留现有数据、导航、快捷键和平台集成。

## Workbench 工作台

- 默认配色使用深色绿系表面、细边框和低饱和强调色，减少渐变、装饰和视觉噪声。
- 重新整理窗口标题栏、左侧导航、总览摘要卡片、状态行和快捷入口的间距与信息层级。
- 使用 Segoe UI Variable Text 作为首选字体，并保留 Microsoft YaHei UI 等中文回退字体。
- 保留 Classic、Ocean、Rose、Terminal 等原有主题，可在设置 → 外观中切换。

## 兼容性

- 保留现有 widget keys、导航回调、刷新/设置/导入/导出流程和 Windows 窗口集成边界。
- 不改变题库、训练、账号、同步、备份和原生题库 companion 的数据协议。
- 项目内新增 `ui-ux-pro-max` 与 `impeccable` skill 资产，以及 `preview/ui-redesign-v1.html` 和对应 SVG，供后续界面迭代复用。

## 下载与验证

推荐下载 `OJ-Float-v0.4.0-windows-x64-setup.exe`。免安装使用请选择完整 ZIP 并保留同目录的 DLL 与 `data`。下载文件的 SHA-256 见 `OJ-Float-v0.4.0-SHA256SUMS.txt`。

安装包仍未进行发行者代码签名；请从本仓库 Releases 下载，并按校验文件验证下载完整性。
