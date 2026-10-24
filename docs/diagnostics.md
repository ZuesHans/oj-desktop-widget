# 诊断日志与导出

本文描述 OJ Float 的诊断日志：记录哪些字段、如何脱敏、轮转策略、失败策略，以及设置页“导出诊断信息”的呈现方式。

## 记录字段

每条日志记录是一个单行 JSON 对象，包含：

| 字段 | 说明 |
| --- | --- |
| `ts` | 记录时间（UTC ISO-8601） |
| `app` | 应用版本与构建号，格式 `版本+build`（如 `0.2.0+8`） |
| `configSchema` | 配置 schema 版本（`currentAppConfigVersion`） |
| `dbSchema` | 题库数据库 schema 版本（`ProblemDatabase.schemaVersion`） |
| `event` | 事件类型：`framework_error`、`unhandled_async_error`、`operation`，或调用方自定义的事件名 |
| `message` | 已脱敏的事件或错误消息 |
| `stack` | 已脱敏的错误堆栈（仅错误记录） |
| `ops` | 最近若干条刷新/导入/恢复操作摘要（已脱敏），见下文 |

超过上限的字段会被截断：消息最多 8 KiB，堆栈最多 16 KiB。操作摘要保留最近 20 条。

## 脱敏规则与别名

脱敏默认开启，不需要用户选择关闭。以下内容**永不写入**日志或导出文件：

- 密码、令牌、Cookie、请求头、原始响应
- 完整题库内容、题目标题正文、笔记、复盘正文

以下内容在写入前会被替换为稳定别名，保证同一逻辑值在不同记录中始终映射到同一别名，便于跨记录关联：

| 内容 | 别名 | 规则 |
| --- | --- | --- |
| OJ 账号名 | `{oj_user_1}`、`{oj_user_2}`… | 按去重后的账号集合字典序编号；编号在本次运行内稳定 |
| 绝对路径中的本机用户名 | `{local_user}` | 匹配 `C:\Users\<name>`、`C:/Users/<name>` 及 `/Users/<name>` 等形态 |
| URL 查询参数值 | `{url_param}` | 保留参数名，值替换为别名 |
| Bearer / 令牌形态的密文 | `{token}` | 匹配 `Bearer <token>` |
| 敏感 `key=value` | `key={redacted}` | 匹配 `password`、`token`、`secret`、`api_key`、`authorization`、`cookie`、`set-cookie`、`access_token`、`refresh_token` 等键 |

脱敏别名常量集中定义在 [`diagnostics_service.dart`](../lib/services/diagnostics_service.dart)：`diagnosticsOjUserAliasPrefix`、`diagnosticsLocalUserAlias`、`diagnosticsUrlParameterAlias`、`diagnosticsTokenAlias`、`diagnosticsSensitiveValueAlias`。

## 轮转参数

| 常量 | 值 | 说明 |
| --- | --- | --- |
| `diagnosticsActiveLogFileName` | `diagnostics.log` | 当前活动日志文件名 |
| `diagnosticsMaxFileBytes` | `1 MiB`（1048576 字节） | 单个文件最大体积 |
| `diagnosticsMaxRotatedFiles` | `5` | 最多保留的轮转文件数（`diagnostics.log.1` 到 `diagnostics.log.5`） |
| `diagnosticsMaxRecentOperations` | `20` | 内存中保留的最近操作摘要数 |

日志写入前若活动文件会超过 1 MiB，则先轮转：删除最旧的 `.5`，把 `.4`→`.5`、…、`.1`→`.2`，再把活动文件改名为 `.1`。磁盘占用因此被限制在约 6 MiB（1 个活动文件 + 5 个轮转文件）。

## 失败策略

- 诊断日志的所有写入路径（创建目录、追加、轮转、导出读取）都捕获并吞掉异常，**绝不**把异常抛回错误处理器，因此不会产生递归异常。
- 写入采用异步“发出后不再等待”的方式，不会阻塞应用正常退出。
- 若日志目录不可写或不存在且无法创建（例如数据目录迁移失败），诊断记录会静默跳过，不影响启动。
- 错误处理器只负责把错误交给诊断服务记录；`FlutterError.presentError` 仍会执行，保留开发期的红屏提示，不吞掉正常退出或恢复流程。

## 错误处理器安装

`main.dart` 在 `runApp` 之前安装两个处理器：

- `FlutterError.onError`：记录框架错误（`framework_error`）。
- `PlatformDispatcher.instance.onError`：记录未处理异步错误（`unhandled_async_error`），返回 `true` 表示已处理。

实现不使用自定义 zone，因此 Flutter binding 初始化与 `runApp` 天然位于同一 zone，也不会重复记录同一错误。

## 操作摘要

`OjController` 在刷新、导入流程中记录简洁摘要；`DataRecoveryService` 在恢复流程中记录：

- `refresh <ojId> ok` 或 `refresh <ojId> error <message>`
- `refresh error <message>`（整轮刷新抛异常时）
- `backup import ok scope=<portable|core_training> rows=N`
- `backup import error <message>`
- `restore ok scope=<portable|core_training>`
- `restore error <message>`

摘要中的账号名、URL 查询参数和错误消息都会先经过脱敏。

## 导出范围呈现

设置页“诊断信息”区块提供“导出诊断信息”按钮。点击后先弹窗告知导出范围：

- 导出文件包含应用版本、配置与数据库 schema 版本、最近刷新/导入/恢复操作摘要、脱敏后的诊断日志。
- 已脱敏：密码、令牌、Cookie、请求头、原始响应、题库正文、笔记与复盘不会记录；OJ 账号、URL 查询参数和绝对路径中的本机用户名会替换为稳定别名。
- 导出仅写入用户选择的本地文件，不自动上传或发送给任何人。

确认后通过 `file_picker` 选择保存位置，写一个自包含的纯文本文件（默认 `oj-diagnostics.txt`），不依赖 zip 或任何新增依赖。
