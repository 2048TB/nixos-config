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
| `docs/ENV-USAGE.md` | 按环境操作指南 |
| `docs/KEYBINDINGS.md` | 桌面快捷键 |
| `docs/REDUCTION-REFACTOR-ANALYSIS.md` | 减法重构分析与目标结构 |
| `nix/hosts/README.md` | 主机目录组织 |
| `nix/home/README.md` | Home Manager 结构 |

---

## 原则

- 优先使用 `just` 命令
- 危险操作需明确目标主机和磁盘
- 密码和 SSH 私钥走 `agenix`，不要明文放进 Git

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
just agenix-init-create
just agenix-recovery-init
```

已有旧密钥（先复制到 `.keys/`）：

```bash
just agenix-init
```

### 1.3 设置密码

```bash
just password-hashes
just password-set-hash '<sha512-hash>'
```

### 1.4 安装

```bash
just host=zly install-check           # 预检
just host=zly disk=/dev/nvme0n1 install  # 安装（会清盘）
```

安装后仓库同步到 `/persistent/nixos-config`，`/etc/nixos` 链接到该目录。

密钥搜索顺序：`./.keys/main.agekey` → `<repo>/.keys/main.agekey` → `~/.keys/main.agekey`

### 1.5 重启后

```bash
just switch
```

---

## 2. 日常更新

```bash
just check        # 构建检查
just test         # 临时激活（重启失效）
just switch       # 正式切换
```

不指定 `host` 时自动检测当前主机（strict 模式）。手动指定：`just host=zly switch`

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
自动检测未匹配仓库主机。用 `just hosts` 查看可用主机，再 `just host=xxx <command>` 指定。

**Q: 密码改了又变回去**
密码来自声明式 secrets。正确做法：`just password-set-hash '<hash>' && just switch`

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

## 6. 目录速览

```
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

## 7. Binary Cache

3 个二进制缓存（减少编译时间）：
- `https://nix-community.cachix.org`
- `https://nixpkgs-wayland.cachix.org`
- `https://cache.garnix.io`

配置位置：`nix/modules/core/nix-settings.nix`
