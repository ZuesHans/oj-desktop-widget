# OJ Float 浏览器导入

这里提供两种 Edge / Chrome 集成方式：

- `manifest.json`：加载解压缩目录的 Manifest V3 扩展；
- [`tampermonkey/`](tampermonkey/README.md)：带猪头悬浮按钮的 Tampermonkey
  一键存题脚本。

## Manifest V3 扩展

1. 启动 OJ Float，在“设置 > 浏览器导入”确认本地服务运行中。
2. 在 Edge 打开 `edge://extensions`，或在 Chrome 打开 `chrome://extensions`。
3. 开启“开发人员模式”，选择“加载解压缩的扩展”，指向本目录。
4. 打开扩展，将桌面端显示的配对令牌填入一次。
5. 在支持的题目页面点击“导入当前题目”。

扩展仅向 `http://127.0.0.1:27121/v1/problems/import` 发送当前页 URL、标题、平台、外部题号、标签和难度。扩展不申请 Cookie 权限，也不读取登录凭据或代替用户提交代码。
