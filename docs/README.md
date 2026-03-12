# Docs

文档入口按职责拆分：

| 文档 | 内容 |
|------|------|
| `README.md` | 仓库根入口 |
| 本文档 | 安装与日常维护 |
| `docs/NIX-COMMANDS.md` | 非日常命令速查 |
| `docs/CI.md` | CI 详细说明与本地等价验证 |
| `docs/ENV-USAGE.md` | 按环境差异与恢复流程 |
| `docs/KEYBINDINGS.md` | 桌面快捷键 |
| `nix/hosts/README.md` | 主机目录组织 |
| `nix/home/README.md` | Home Manager 结构 |
| `secrets/keys/README.md` | 公钥目录与 sops 流程 |

---

## 原则

- 优先使用 `just` 命令
- 危险操作需明确目标主机和磁盘
- 密码和 SSH 私钥走 `sops-nix`，不要明文放进 Git
- 主账号开发环境默认由 Home Manager 提供，system layer 仅保留桌面运行基线
- `repo-check` 是仓库级默认自检入口；CI/workflow 相关改动优先先跑它
- host metadata 统一从 `nix/hosts/registry/systems.toml` 进入 `my.host`，再派生为 `my.capabilities` 供模块消费
- registry 当前承载 `system`、`kind`、`formFactor`、`desktopSession`、`desktopProfile`、`tags`、`gpuVendors`、`displays` 与 deploy 元数据；不要重新引入 `profiles`
- `displays` 是桌面 monitor 拓扑唯一事实源；`Niri` / `Noctalia` 只消费生成结果，不再硬编码真实 monitor 名
- `tags` 只保留不能稳定派生的事实；`multi-monitor` / `hidpi` 这类 display facts 不再手写
- Linux `desktopProfile` 当前只支持 `niri`；Darwin 使用 `aqua`
- Linux NixOS/Home Manager 入口统一走 auto-discovered `_mixins`；新增 self-gating 模块时不要再维护手写 import list
- NixOS host 目录默认只保留 `hardware.nix` / `hardware-modules.nix` / `disko.nix` / `vars.nix`；不要重新引入薄壳 `default.nix`
- 读路径的 flake eval/build/check 默认优先走仓库脚本，以便在 `.keys/main.agekey` 不可读时自动切到 filtered flake repo

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
nix shell nixpkgs#just -c just host=zly install-check
nix shell nixpkgs#just -c just host=zly disk=/dev/nvme0n1 install   # 会清盘
```

安装后仓库同步到 `/persistent/nixos-config`，`/etc/nixos` 链接到该目录。

密钥搜索顺序：`./.keys/main.agekey` → `<repo>/.keys/main.agekey` → `~/.keys/main.agekey`

### 1.5 重启后

```bash
# 仅当缺失时补装：
[ -f /persistent/keys/main.agekey ] || sudo install -D -m 0400 .keys/main.agekey /persistent/keys/main.agekey
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
- 当前 `justfile` 默认 `host := ""`、`darwin_host := ""`；`just switch/check/test` 与 `just darwin-switch/darwin-check` 未显式指定时会自动检测当前主机。
- 跨主机执行时，建议显式指定 `host=...` / `darwin_host=...`。

远程部署（按主机元数据）：
```bash
just deploy
just deploy HOSTS=zly,zky
```

## 2.1 开发环境归属

- Linux/macOS 主账号的一致开发环境（如 `neovim`、Rust、Go、Node.js、Python、`uv`）由 Home Manager 的 `home.packages` 提供
- system layer 保留桌面运行基线（如 `fcitx5`、fonts、portal、`xwayland-satellite`）
- 查看当前声明的 system 包与主用户 HM 包：`just packages`

---

## 3. macOS

```bash
just darwin-check
just darwin-switch
```

说明：在 `zly-mac` 本机上可直接运行以上命令；跨主机执行时请显式指定：`just darwin_host=zly-mac darwin-switch`

---

## 4. 常见问题

**Q: `strict mode requires a valid host`**  
自动检测未匹配仓库主机。先 `just hosts` 查看可用主机，再显式指定：`just host=xxx <command>`。

**Q: 密码改了又变回去**  
密码来自声明式 secrets。正确做法：`just password-set-hash '<hash>' && just host=<nixos-host> switch`。

**Q: 找不到 `main.agekey`**  
放到 `./.keys/main.agekey`、`<repo>/.keys/main.agekey` 或 `~/.keys/main.agekey` 中任一位置。

**Q: 直接执行 `nix eval path:/persistent/nixos-config#...` 报 `.keys/main.agekey: Permission denied`**  
真实 checkout 可能包含 root-only 的 `.keys/main.agekey`。优先用 `just eval-tests`、`just flake-check`、`just repo-check`，或先执行 `flake_repo="$(bash nix/scripts/admin/print-flake-repo.sh /persistent/nixos-config)"`，再对 `path:$flake_repo#...` 做 eval/build。

**Q: 如何防止密钥泄露**
```bash
just hooks-enable
just guard-secrets
```

---

## 5. 提交前验证

```bash
just repo-check
```

最小检查：

```bash
just eval-tests
just flake-check
```

如改动了 shell 脚本、workflow 或 registry/check 逻辑，优先补：

```bash
just repo-check
```

---

## 6. CI（GitHub Actions）

- 默认门禁：`Nix CI Light`（PR/Push 自动触发，含 registry check、eval checks 与 1 台代表性 host build）
- 保留重型：`Nix CI Heavy (Manual)`（仅手动触发）
- 保留 lock 检查：`Flake Lock Checker Heavy (Manual)`（仅手动触发）
- 自动清理：`Cleanup Old Workflow Runs`（按周期清理旧 runs）
- 文档/Markdown-only 变更默认不会触发 `Nix CI Light`
- 详情见：`docs/CI.md`

---

## 7. 目录速览

```text
nixos-config/
├── nix/
│   ├── lib/              # Nix 库函数
│   ├── hosts/            # 主机配置（nixos/ + darwin/ + registry/ + outputs/）
│   ├── modules/          # 系统模块（core/_mixins + darwin/）
│   ├── overlays/         # 对外复用 overlay 导出面
│   ├── pkgs/             # 本地 package 导出面
│   ├── home/             # Home Manager 配置（linux/_mixins + configs）
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

---

## 9. Flake 导出面

- `overlays`：对外复用 overlay
- `packages`：对外复用本地 package 集
- `nixosModules`：对外复用系统模块
