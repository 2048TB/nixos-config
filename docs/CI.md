# CI（GitHub Actions）

本仓库使用 GitHub Actions 做 2 类 CI：

1. `Nix CI`：PR/Push（`main`）与手动触发  
2. `Flake Lock Checker`：定时巡检 `flake.lock` 健康度

---

## 1. Nix CI 流程

工作流文件：`.github/workflows/ci.yml`

执行顺序：

1. `inventory`：动态发现 `nixosConfigurations` / `darwinConfigurations`
2. `flake-check`：执行 `nix flake check --all-systems --show-trace`
3. `nixos-build`：按 host matrix 构建每台 NixOS 的 `config.system.build.toplevel`
4. `darwin-eval`：按 host matrix 校验 Darwin `system.drvPath`

设计目标：
- 不手写 host 列表，避免新增主机后漏测
- `flake-check` 负责统一质量门
- Linux runner 上对 Darwin 做 eval 校验，避免跨平台构建失败噪音

---

## 2. Flake Lock Checker

工作流文件：`.github/workflows/flake-lock-checker.yml`

- 每周一 UTC `03:17` 自动执行
- 也可手动触发（`workflow_dispatch`）
- 使用 `DeterminateSystems/flake-checker-action` 检查 lock freshness 与依赖健康

---

## 3. 本地等价验证（与 CI 对齐）

```bash
# 1) inventory
nix eval --json .#nixosConfigurations --apply builtins.attrNames
nix eval --json .#darwinConfigurations --apply builtins.attrNames

# 2) flake-check
just flake-check

# 3) nixos host builds
for h in $(nix eval --json .#nixosConfigurations --apply builtins.attrNames | jq -r '.[]'); do
  nix build --no-link -L ".#nixosConfigurations.${h}.config.system.build.toplevel"
done

# 4) darwin eval
for h in $(nix eval --json .#darwinConfigurations --apply builtins.attrNames | jq -r '.[]'); do
  nix eval --raw ".#darwinConfigurations.${h}.system.drvPath" >/dev/null
done
```

说明：本地循环命令依赖 `jq`。若无 `jq`，请先安装或改用 `nix eval` 的 `--apply` 方式处理列表。

---

## 4. 手动触发 CI

GitHub 页面：
- `Actions -> Nix CI -> Run workflow`
- `Actions -> Flake Lock Checker -> Run workflow`

CLI：

```bash
gh workflow run "Nix CI" --ref <branch>
gh workflow run "Flake Lock Checker" --ref <branch>
gh run list --limit 10
gh run watch <run-id>
```

