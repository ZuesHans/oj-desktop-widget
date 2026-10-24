# Toolchain pinning, upgrade, and release provenance

更新日期：2026-10-24（Asia/Shanghai）

本文记录 CI 与本地开发使用的 Flutter 工具链固定版本、本地验证方式、升级流程，以及依赖更新与发布来源证明的验证方法。

## 1. 固定版本

CI 通过 [`ci.yml`](../.github/workflows/ci.yml) 中的 `subosito/flutter-action@v2` 固定 Flutter 版本：

```yaml
- uses: subosito/flutter-action@v2
  with:
    channel: stable
    flutter-version: 3.44.2
    cache: true
```

固定版本为 **Flutter 3.44.2（stable）**，对应 Dart 3.12.2。`channel: stable` 与 `flutter-version` 同时给出，`flutter-version` 精确指定版本、channel 保持一致，避免 CI 随稳定通道滚动更新。

## 2. 本地验证方式

固定值来自本机实测，不是文档猜测。验证命令与输出如下：

```powershell
flutter --version
```

```
Flutter 3.44.2 • channel stable • https://github.com/flutter/flutter.git
Framework • revision c9a6c48423 (5 months ago) • 2026-06-10 15:52:41 -0700
Engine • hash 04efd7c093d4e9281d5526ebcad6ecc60ba8badf (revision 77e2e94772) (4 months ago) • 2026-06-10 19:59:06.000Z
Tools • Dart 3.12.2 • DevTools 2.57.0
```

只有在本机确认某一版本完整通过下面的升级链路后，才把该版本写入 `ci.yml`。

## 3. 升级流程（本地与 CI 保持同步）

1. 在本机安装/激活目标版本（例如 `flutter upgrade` 或切到对应 channel），运行 `flutter --version` 确认版本号与 channel。
2. 更新 [`ci.yml`](../.github/workflows/ci.yml) 中 `flutter-version` 为刚验证过的精确版本，保持 `channel` 与目标版本一致。
3. 更新依赖并逐项执行现有检查：
   ```powershell
   flutter pub get
   dart format --output=none --set-exit-if-changed lib test
   flutter analyze
   flutter test --coverage
   ./scripts/check_coverage.ps1
   ```
4. 构建 Windows release 与原生 companion：
   ```powershell
   flutter build windows --release
   ./native_companion/build.ps1
   ```
5. 打包安装包与便携包（本机入口见 [`build_windows_release_ninja.ps1`](../scripts/build_windows_release_ninja.ps1)；CI 使用 `bootstrap_inno.ps1` + `package_windows_release.ps1`）：
   ```powershell
   $compiler = ./scripts/bootstrap_inno.ps1
   ./scripts/package_windows_release.ps1 -SkipBuild -InnoCompiler $compiler
   ```
6. 安装/覆盖/卸载冒烟测试：
   ```powershell
   ./scripts/smoke_windows_installer.ps1
   ```
7. 将 pin 与文档改动提交到同一 PR；CI 会在 `pull_request` 上重跑同一链路（format / analyze / test / coverage / 浏览器 fixtures / native companion / build / package / install smoke）。全部通过后再合入。

## 4. Dependabot 依赖更新

[`dependabot.yml`](../.github/dependabot.yml) 为两个生态开启每周更新：

- `github-actions`（Actions 版本）
- `pub`（Dart/Flutter 依赖）

Dependabot 的更新 PR 通过 `pull_request` 触发同一个 CI workflow，因此必须通过现有完整链路——format、analyze、test、coverage、浏览器 fixtures、native companion 构建、Windows release 构建、打包与安装/覆盖/卸载冒烟——才能合入。升级 Flutter SDK 本身不经过 Dependabot，走第 3 节的固定版本升级流程。

## 5. 发布来源证明（provenance）验证

每次 tag 发布时，publish job 会在 `gh release create` 之前用 `actions/attest-build-provenance@v2` 对 `dist/` 中的最终资产（zip、setup exe、SHA256SUMS.txt）生成来源证明，把仓库、提交、workflow 与资产摘要绑定。

用户下载资产后，可用 GitHub CLI 验证（`--source-ref` 强制匹配发布 tag）：

```powershell
gh attestation verify OJ-Float-vX.Y.Z-windows-x64-setup.exe --repo ZuesHans/oj-desktop-widget --source-ref refs/tags/vX.Y.Z
```

例如对 v0.3.0：

```powershell
gh attestation verify OJ-Float-v0.3.0-windows-x64-setup.exe --repo ZuesHans/oj-desktop-widget --source-ref refs/tags/v0.3.0
```

说明：

- `SHA256SUMS.txt` 只保证**传输完整性**（下载到的字节与发布时一致）；它和资产在同一个 release 里发布，属于**同源**，不构成独立的发布者身份。
- provenance / attestation 才把**仓库、提交、workflow** 绑定到资产摘要，用于回答“这个文件确实由该仓库的该次 workflow 构建”。
- 发布者身份认证仍由签名（T10-C）补足；签名或打包改变资产后，哈希与来源证明必须重新生成（正确顺序：构建 → 签二进制 → 打包 → 签安装器 → 生成哈希和来源证明 → 发布）。
