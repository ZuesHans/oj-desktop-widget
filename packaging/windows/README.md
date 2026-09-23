# OJ Float Windows 版

这个压缩包同时包含完整的 Flutter 客户端、轻量 C++ 题库小程序和猪猪一键存题
Tampermonkey 脚本。

## 完整客户端

运行 `oj_float.exe`。请不要把它单独移出本目录；Flutter 运行库和 `data` 目录是必需的。

## 轻量题库与浏览器存题

1. 运行 `oj_problem_companion.exe`。
2. 在 Edge 安装 Tampermonkey。
3. 从 Tampermonkey 管理面板的“实用工具 → 从文件导入”选择
   `oj-float-importer.user.js`。
4. 浏览题目页面时点击右下角的猪头按钮。

油猴脚本只连接 C++ 小程序的 `127.0.0.1:27122` 服务，日常存题不需要保持
`oj_float.exe` 运行。若这台电脑还没有题库数据库，首次启动 C++ 小程序会短暂调用
同目录的 `oj_float.exe` 完成一次数据库迁移，之后即可独立运行。

不要单独复制 C++ EXE：`sqlite3.dll` 必须与它放在同一目录。
