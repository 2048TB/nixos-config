# Docs

当前仓库已收敛到最小脚本 surface，文档只覆盖保留入口：

| 文档 | 内容 |
|------|------|
| `README.md` | 仓库根入口 |
| 本文档 | 安装、锁更新与 secrets 日常维护 |
| `docs/NIX-COMMANDS.md` | 精简命令速查 |
| `docs/ENV-USAGE.md` | 按环境差异的安装与恢复说明 |
| `docs/KEYBINDINGS.md` | 桌面快捷键 |
| `nix/hosts/README.md` | 主机目录组织 |
| `nix/home/README.md` | Home Manager 结构 |
| `secrets/keys/README.md` | 公钥目录与 sops 流程 |

---

## 原则

- 优先使用保留的脚本入口，不依赖已移除的 repo-check / rebuild / deploy 包装层
- 危险操作必须显式写主机和磁盘
- read-only flake inspect 优先先取 filtered repo，避免 `.keys/main.agekey` 权限问题
- secrets 只通过 `sops.sh` 和 `guard-secrets.sh` 维护

---

## 1. 首次安装（Live ISO）

### 1.1 获取配置

```bash
git clone https://github.com/2048TB/nixos.git ~/nixos
cd ~/nixos
```

### 1.2 初始化密钥

全新环境：

```bash
just sops-init-create
just sops-recovery-init
```

已有旧密钥（先复制到 `.keys/`）：

```bash
just sops-init
```

### 1.3 设置密码

```bash
just password-hashes
just password-set-hash '<sha512-hash>'
```

### 1.4 安装

若当前环境尚未开启 flakes（如 Live ISO），先执行：

```bash
export NIX_CONFIG="experimental-features = nix-command flakes"
```

```bash
nix shell nixpkgs#just -c just host=zly disk=/dev/nvme0n1 install
```

或直接调用脚本：

```bash
REPO="$PWD"
bash "$REPO/nix/scripts/admin/install-live.sh" --host zly --disk /dev/nvme0n1 --repo "$REPO"
```

安装后仓库同步到 `/persistent/nixos-config`，`/etc/nixos` 链接到该目录。

---

## 2. Flake 与锁文件

更新所有输入：

```bash
just update
```

只更新 `nixpkgs`：

```bash
just update-nixpkgs
```

查看 flake 信息：

```bash
just info
```

如果真实 checkout 包含不可读的 `.keys/main.agekey`，不要直接对 `path:/persistent/nixos-config` 做 read-only eval/show。先取 filtered repo：

```bash
REPO=/persistent/nixos-config
flake_repo="$(bash "$REPO/nix/scripts/admin/print-flake-repo.sh" "$REPO")"
nix flake show "path:$flake_repo"
```

---

## 3. Secrets 与 Git 安全

```bash
just hooks-enable
just guard-secrets
just sops-init-create
just sops-recovery-init
just sops-recipients
just sops-rekey
just ssh-key-set
```

---

## 4. 常见问题

**Q: 直接执行 `nix eval path:/persistent/nixos-config#...` 报 `.keys/main.agekey: Permission denied`**
先执行：

```bash
flake_repo="$(bash nix/scripts/admin/print-flake-repo.sh /persistent/nixos-config)"
```

再对 `path:$flake_repo#...` 做 `eval` / `build` / `show`。

**Q: `just update` 仍失败**
确认当前仓库根目录可写，并检查 `flake.lock` 没有只读权限。`update-flake.sh` 会在需要时先更新 filtered repo，再把新的 `flake.lock` 同步回真实仓库。

**Q: 找不到 `main.agekey`**
放到 `./.keys/main.agekey`、`<repo>/.keys/main.agekey` 或 `~/.keys/main.agekey` 中任一位置。

**Q: 如何防止密钥泄露**

```bash
just hooks-enable
just guard-secrets
```
