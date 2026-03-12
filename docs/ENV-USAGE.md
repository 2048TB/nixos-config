# 多环境使用手册

按 3 种环境拆分：Live ISO / 已安装 NixOS / 其他环境中的只读 flake 操作。通用入口见 `docs/README.md`。

---

## 通用约定

- 已安装系统的推荐仓库路径：`/persistent/nixos-config`
- Live ISO / 临时环境可直接在任意可写目录使用当前 checkout，例如 `~/nixos`
- 当前仓库保留的脚本只有：
  - `install-live.sh`
  - `print-flake-repo.sh`
  - `update-flake.sh`
  - `sops.sh`
  - `guard-secrets.sh`
  - `common.sh`（内部依赖）

---

## 1. Live ISO（安装 NixOS）

### 启用 flakes

```bash
export NIX_CONFIG="experimental-features = nix-command flakes"
```

### 安装

```bash
nix shell nixpkgs#just -c just host=zly disk=/dev/nvme0n1 install
```

或直接调用脚本：

```bash
REPO="$PWD"
bash "$REPO/nix/scripts/admin/install-live.sh" --host zly --disk /dev/nvme0n1 --repo "$REPO"
```

说明：脚本会再次确认目标磁盘；自动化环境中需要显式传 `--yes`。

### 密钥搜索路径

`./.keys/main.agekey` → `<repo>/.keys/main.agekey` → `~/.keys/main.agekey`

---

## 2. 已安装 NixOS

当前已不再保留 `switch/check/test` 包装脚本。
已安装系统上的常规维护主要剩下两类：

1. 更新 lock：

```bash
just update
just update-nixpkgs
```

2. 维护 secrets：

```bash
just sops-recipients
just sops-rekey
```

---

## 3. 其他环境中的只读 flake 操作

如果 checkout 中存在不可读的 `.keys/main.agekey`，不要直接对原始 repo 执行：

```bash
nix eval path:/persistent/nixos-config#...
```

先取 filtered repo：

```bash
REPO=/persistent/nixos-config
flake_repo="$(bash "$REPO/nix/scripts/admin/print-flake-repo.sh" "$REPO")"
nix flake show "path:$flake_repo"
nix eval "path:$flake_repo#nixosConfigurations" --apply builtins.attrNames
```

---

## 4. 常见报错

| 报错 | 处理 |
|------|------|
| `path:<repo>` 评估时报 `.keys/main.agekey: Permission denied` | 先调用 `print-flake-repo.sh` 获取 filtered repo |
| `just update` 报 `.keys/main.agekey: Permission denied` | 现在应改为走 `update-flake.sh`；若仍失败，检查仓库根目录和 `flake.lock` 是否可写 |
| 找不到 `main.agekey` | 放到 `.keys/main.agekey`（或脚本搜索路径中的其他位置） |
