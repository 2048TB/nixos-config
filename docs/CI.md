# CI（GitHub Actions）

本仓库使用 GitHub Actions 做 4 类流程：

1. `Nix CI Light`：默认 PR/Push 轻量门禁（启用）  
2. `Nix CI Heavy (Manual)`：完整重型检查（保留，仅手动）  
3. `Flake Lock Checker Heavy (Manual)`：lock 健康检查（保留，仅手动）
4. `Cleanup Old Workflow Runs`：自动清理旧 Actions runs（启用）

补充：`Nix CI Light` 对 `docs/**`、`**/*.md`、`wallpapers/**` 使用了 `paths-ignore`，所以文档-only 变更默认不会触发该工作流。

---

## 1. 默认轻量 CI

工作流文件：`.github/workflows/ci-light.yml`

触发方式：
- `pull_request`（`main`）
- `push`（`main`）
- `workflow_dispatch`

检查内容：
1. 解析并校验 host registry（`bash nix/scripts/checks/registry-check.sh`）
2. build Linux eval checks（`evaltest-hostname/home/kernel/platform`）
3. build 1 台代表性 NixOS host（当前固定为 `zly`）
4. eval Darwin checks（`evaltest-darwin-hostname/home/platform`）

设计目标：尽快反馈，同时保证至少有 1 个真实 Linux toplevel build。

---

## 2. 保留的重型 CI（手动）

工作流文件：`.github/workflows/ci-heavy.yml`

触发方式：仅 `workflow_dispatch`

执行顺序：
1. `inventory`：动态发现 hosts
2. `flake-check`：`nix flake check --all-systems`
3. `nixos-build`：逐 host 构建 `config.system.build.toplevel`
4. `darwin-eval`：逐 host eval `system.drvPath`

说明：当配置接近稳定时可切回此流程作为默认门禁。

---

## 3. 保留的 lock 检查（手动）

工作流文件：`.github/workflows/flake-lock-checker.yml`

触发方式：仅 `workflow_dispatch`

用途：按需运行 `DeterminateSystems/flake-checker-action`。

---

## 4. 自动清理旧运行记录（启用）

工作流文件：`.github/workflows/cleanup-workflow-runs.yml`

触发方式：
- `schedule`：每周日 UTC `03:27`
- `workflow_dispatch`

清理策略：
- 删除“已完成（completed）且创建时间超过 30 天”的 workflow runs
- 不删除进行中 runs

---

## 5. 本地等价验证（轻量 CI）

```bash
just eval-tests
```

仓库级建议：

```bash
just repo-check
```

完整本地重检查（含 dry-build）：

```bash
bash nix/scripts/admin/repo-check.sh --full
```

---

## 6. 手动触发 CI

GitHub 页面：
- `Actions -> Nix CI Light -> Run workflow`
- `Actions -> Nix CI Heavy (Manual) -> Run workflow`
- `Actions -> Flake Lock Checker Heavy (Manual) -> Run workflow`
- `Actions -> Cleanup Old Workflow Runs -> Run workflow`

CLI：

```bash
gh workflow run "Nix CI Light" --ref <branch>
gh workflow run "Nix CI Heavy (Manual)" --ref <branch>
gh workflow run "Flake Lock Checker Heavy (Manual)" --ref <branch>
gh workflow run "Cleanup Old Workflow Runs" --ref <branch>
gh run list --limit 10
gh run watch <run-id>
```
