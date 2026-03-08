# NixOS 多主机配置

可复现的多主机配置仓库：
- NixOS：`zly`、`zky`、`zzly`（NixOS + Home Manager）
- macOS：`zly-mac`（nix-darwin + Home Manager）

---

## 快速导航

| 文档 | 内容 |
|------|------|
| 本文档 | 安装与日常维护 |
| `docs/NIX-COMMANDS.md` | 命令速查 |
| `docs/CI.md` | GitHub Actions 与本地等价验证 |
| `docs/ENV-USAGE.md` | 按环境操作指南 |
| `docs/KEYBINDINGS.md` | 桌面快捷键 |
| `docs/REDUCTION-REFACTOR-ANALYSIS.md` | 减法重构分析与目标结构 |
| `nix/hosts/README.md` | 主机目录组织 |
| `nix/home/README.md` | Home Manager 结构 |
| `secrets/keys/README.md` | 公钥目录与 sops 流程 |

---

## 原则

- 优先使用 `just` 命令
- 危险操作需明确目标主机和磁盘
- 密码和 SSH 私钥走 `sops-nix`，不要明文放进 Git

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

```bash
just host=zly install-check
just host=zly disk=/dev/nvme0n1 install   # 会清盘
```

安装后仓库同步到 `/persistent/nixos-config`，`/etc/nixos` 链接到该目录。

密钥搜索顺序：`./.keys/main.agekey` → `<repo>/.keys/main.agekey` → `~/.keys/main.agekey`

### 1.5 重启后

```bash
sudo install -D -m 0400 .keys/main.agekey /persistent/keys/main.agekey
just host=zly switch
```

---

## 2. 日常更新

```bash
just host=zly check
just host=zly test
just host=zly switch
```

说明：
- 当前 `justfile` 默认 `host := "zzly"`，`just switch/check/test` 未显式指定时会使用该默认值。
- 如需自动检测主机，请使用 flake apps（`nix run .#build-switch`）或在本地调整 `justfile` 的默认 `host`。

---

## 3. macOS

```bash
just darwin-check
just darwin-switch
```

手动指定：`just darwin_host=zly-mac darwin-switch`

---

## 4. 常见问题

**Q: `strict mode requires a valid host`**  
自动检测未匹配仓库主机。先 `just hosts` 查看可用主机，再显式指定：`just host=xxx <command>`。

**Q: 密码改了又变回去**  
密码来自声明式 secrets。正确做法：`just password-set-hash '<hash>' && just host=<nixos-host> switch`。

**Q: 找不到 `main.agekey`**  
放到 `./.keys/main.agekey`、`<repo>/.keys/main.agekey` 或 `~/.keys/main.agekey` 中任一位置。

**Q: 如何防止密钥泄露**
```bash
just hooks-enable
just guard-secrets
```

---

## 5. 提交前验证

```bash
just eval-tests
just flake-check
```

---

## 6. CI（GitHub Actions）

- 默认门禁：`Nix CI Light`（PR/Push 自动触发，快速 eval checks）
- 保留重型：`Nix CI Heavy (Manual)`（仅手动触发）
- 保留 lock 检查：`Flake Lock Checker Heavy (Manual)`（仅手动触发）
- 自动清理：`Cleanup Old Workflow Runs`（按周期清理旧 runs）
- 详情见：`docs/CI.md`

---

## 7. 目录速览

```text
nixos-config/
├── nix/
│   ├── lib/              # Nix 库函数
│   ├── hosts/            # 主机配置（nixos/ + darwin/ + outputs/）
│   ├── modules/          # 系统模块（core/ + darwin/）
│   ├── home/             # Home Manager 配置
│   └── scripts/          # 脚本（admin/）
├── secrets/              # 加密 secrets（可提交）
├── wallpapers/           # 壁纸
├── docs/                 # 文档
├── justfile              # 命令入口
└── flake.nix             # Flake 入口
```

---

## 8. Binary Cache

3 个二进制缓存（减少编译时间）：
- `https://nix-community.cachix.org`
- `https://nixpkgs-wayland.cachix.org`
- `https://cache.garnix.io`

配置位置：`nix/modules/core/nix-settings.nix`
