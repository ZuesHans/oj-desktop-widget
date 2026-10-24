# 仓库体积治理：测量记录与历史重写方案（T03-C）

状态：已测量，待维护者确认后再执行。本文不包含任何已执行的重写操作。

更新日期：2026-10-24

## 1. 测量结果

```text
git count-objects -vH
  count: 3198  size-pack: 17.64 MiB
```

可达历史中最大的对象（`git rev-list --objects --all | git cat-file --batch-check`）：

| 大小 | 对象 | 说明 |
| --- | --- | --- |
| 15.38 MB | `v0.1.1-beta v2.zip` | 旧安装包；当前仍被 `main` 跟踪，根目录可见。替代下载位置：GitHub Releases 的对应版本资产。首次加入提交 `4df2ac1`，从未删除。 |
| 15.36 MB | `OJ-Float-v0.1.0-beta.1-windows-x64.zip` | 旧安装包，仅存在于历史。替代下载位置：GitHub Releases。 |
| ~10 × ~1 MB | `.omo/evidence/.../*.png` | 旧评测截图（紧凑窗/大浮窗时代的界面，已被 v0.2.0 移除），主要随 `codex/oj-sync-webhook-clean` 等旧分支可达。 |

当前仍被引用、不能删除的图片（app 与浏览器脚本在用的 PNG）约 4.5 MB：`assets/app_icon.png`（1.99 MB）、`native_companion/resources/oj_problem_companion.png`（1.27 MB）、`browser_extension/tampermonkey/assets/pig-head.png`（1.17 MB）。

结论：重写的最大收益是移除两个旧安装包 zip（约 30.8 MB 原始体积，zip 本身不可再压缩，因此基本等比例反映到 pack 大小），其次是清理旧分支上的 `.omo` 截图证据。

## 2. 执行方案（草案，未经维护者确认）

1. **备份**：`git clone --mirror` 到本地备份目录，并保留一份 GitHub 侧引用（如确认重写前再导出一次 issue 引用不受影响的检查）。确认 Releases 中已有两个旧安装包资产可下载（作为替代下载位置）。
2. **工具**：优先 `git filter-repo`（Python），替代 BFG。
3. **规则**：`--path "v0.1.1-beta v2.zip" --path "OJ-Float-v0.1.0-beta.1-windows-x64.zip" --path-glob ".omo/evidence/*" --invert-paths`；只删对象，不改动任何提交信息。
4. **受影响分支与协作者**：`main`、`codex/*` 历史中所有可达这些对象的提交都会被重写。执行前确认没有协作者持有未推送的旧提交；重写后所有人需重新 clone 或 `git reset --hard origin/main`（有本地未提交内容者先备份）。
5. **维护窗口**：由维护者确认一个低活跃窗口。禁止将强制推送混入任何展示/功能 PR。
6. **推送与验证**：`git push --force-with-lease` 各受影响分支与标签；随后全新 clone 验证：
   - `git count-objects -vH` 明显下降；
   - `git log` 关键提交仍在、Release 资产下载链接可用；
   - CI 正常触发。
7. **记录**：完成后在协作文档登记日期、工具、规则、受影响分支和全新 clone 验证结果。

## 3. 不执行的内容

- 不删除当前 app 与浏览器脚本引用的 PNG。
- 不在未确认维护窗口时重写并强推。
- 不把本次测量当作“clone 体积已下降”的验收结果。
