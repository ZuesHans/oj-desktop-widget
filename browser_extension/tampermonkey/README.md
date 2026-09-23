# OJ Float 猪猪一键存题（Tampermonkey）

这个油猴脚本在 Edge 的网页右下角显示一个猪头按钮。点击后，它会解析当前题目的
标题、平台、外部题号、标签和难度，并发送给本机 C++ 题库小程序；不认识的网站仍
会保存当前 URL 和能取得的页面标题。Flutter 主程序不需要运行。

## 安装

1. 在 Edge 扩展商店安装 Tampermonkey（油猴）。
2. 启动 `oj_problem_companion.exe`，状态栏会显示浏览器导入监听地址。
3. 打开 Tampermonkey 管理面板，选择“实用工具 → 从文件导入”。
4. 选择本目录中的 `oj-float-importer.user.js`，然后确认安装。
5. 打开任意 HTTP/HTTPS 题目页面，点击右下角猪头。

也可以从 Tampermonkey 菜单执行“保存当前题目”。

## 工作方式与限制

- 请求只发往 `http://127.0.0.1:27122/v1/problems/import`。
- 脚本不申请 Cookie 访问权限，也不读取登录凭据或提交代码。
- 只需保持 C++ 题库小程序运行；Flutter 主程序可以完全关闭。
- C++ 服务只监听回环地址，并要求油猴专用请求头；它不返回 CORS 许可，因此普通
  网页脚本不能直接向题库写入数据。
- 未识别的平台使用 `other`；解析不到题号、标签或难度不影响 URL 保存。
- 同一题再次导入时由桌面端按平台题号或规范化 URL 去重并合并元数据。

## 开发

源模板位于 `src/oj-float-importer.user.template.js`。猪头 PNG 会由构建脚本以内嵌
data URL 写入最终 `.user.js`，安装后不依赖远程图片：

```powershell
.\browser_extension\tampermonkey\build.ps1
node .\browser_extension\tampermonkey\test\importer.test.js
```
