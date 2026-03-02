# NixOS 多主机配置（新手版）

这是一个可复现的多主机配置仓库：
- Linux 主机：`zly`、`zky`、`zzly`（NixOS + Home Manager）
- macOS 主机：`zly-mac`（nix-darwin + Home Manager）

如果你是第一次接触 NixOS，请先看这份文档，再按命令一步步执行。

---

## 你先看哪里

1. 本文档：第一次安装与日常维护
2. `ENV-USAGE.md`：按环境操作（ISO / 已安装 NixOS / macOS）
3. `NIX-COMMANDS.md`：命令速查

补充文档：
- `KEYBINDINGS.md`：桌面快捷键
- `hosts/README.md`：多主机目录怎么组织
- `nix/home/README.md`：Home Manager 配置结构

---

## 一句话原则

- 优先使用 `just` 命令，不直接手写长 `nix` 命令。
- 危险操作只在明确目标主机和磁盘后执行。
- 密码和 SSH 私钥走 `agenix`，不要明文放进 Git。

---

## 0. 安装前准备

你需要：
- 一台目标机器（要安装 NixOS）
- NixOS Live ISO 启动盘
- 网络
- 一个 U 盘（可选，但强烈推荐）

仓库默认路径建议：`/persistent/nixos-config`

---

## 1. 第一次安装 NixOS（最常用）

以下流程在 **Live ISO** 环境执行。

### 1.1 获取配置

```bash
git clone https://github.com/2048TB/nixos.git ~/nixos
cd ~/nixos
```

### 1.2 初始化密钥（只做一次）

如果你是全新环境、没有旧密钥：

```bash
just agenix-init-create
just agenix-recovery-init
```

如果你已经有旧密钥（例如 U 盘里有 `.keys/main.agekey`），先复制旧密钥到仓库 `.keys/`，然后：

```bash
just agenix-init
```

### 1.3 设置系统登录密码（必须）

```bash
just password-hashes
just password-set-hash '<你的 sha512 哈希>'
```

说明：本仓库 `users.mutableUsers = false`，系统密码以 `secrets/passwords/*.age` 为准。

### 1.4 安装前检查（建议）

```bash
just host=zly install-check
# 或目标是另一台
just host=zky install-check
```

### 1.5 执行安装（危险，会清盘）

```bash
just host=zly disk=/dev/nvme0n1 install
# 或
just host=zky disk=/dev/nvme0n1 install
```

安装脚本会在 `nixos-install` 后将当前仓库原子同步到 `/persistent/nixos-config`，并将 `/etc/nixos` 链接到该目录。
安装时用于解密 secrets 的 `main.agekey` 会按顺序查找：`./.keys/main.agekey` → `<repo>/.keys/main.agekey` → `~/.keys/main.agekey`（必须是 `AGE-SECRET-KEY-*` 私钥文件）。
如果你看到 `~/nixos` 内容异常，先检查：

```bash
readlink -f ~/nixos
ls -la /persistent/nixos-config
```

### 1.6 重启后第一次切换

```bash
just switch
```

---

## 2. 日常更新（已安装 NixOS）

推荐顺序：

```bash
just check
just test
just switch
# 或只在下次启动生效
just boot
```

说明：不指定 `host` 时自动检测当前主机（strict 模式：仅 `NIXOS_HOST` 或当前 hostname）。

手动指定主机：

```bash
just host=zly switch
just host=zky switch
```

---

## 3. macOS（nix-darwin）

在 macOS 主机执行：

```bash
just darwin-check
just darwin-switch
```

说明：不指定 `darwin_host` 时自动检测（仅 `DARWIN_HOST` 或当前 hostname）。

手动指定：

```bash
just darwin_host=zly-mac darwin-check
just darwin_host=zly-mac darwin-switch
```

补充：`nix run .#build` / `.#build-switch` / `.#apply` 也使用 strict 主机解析（环境变量或当前 hostname）。

---

## 4. 常见问题（新手高频）

### Q1: `strict mode requires a valid host` 是什么？

自动检测未能匹配到仓库里的主机。

处理：

```bash
just hosts
just host=zly <command>
```

### Q2: 为什么我 `passwd` 改了密码，后面又变回去了？

因为密码来自声明式 secrets（`secrets/passwords/*.age`）。

正确做法：

```bash
just password-hashes
just password-set-hash '<sha512-hash>'
just switch
```

### Q3: 安装时报找不到 `main.agekey`

把私钥放到以下任一位置（按此顺序查找）：`./.keys/main.agekey`、`<repo-root>/.keys/main.agekey`、`~/.keys/main.agekey`，再重试安装命令。

### Q4: 怎么避免把密钥提交到 GitHub？

```bash
just hooks-enable
just guard-secrets
```

---

## 5. 验证（提交前建议）

```bash
just scripts-check
just eval-tests
just flake-check
```

---

## 6. 目录速览（知道在哪改就够了）

- `hosts/nixos/<host>/`：每台 NixOS 主机配置
- `hosts/nixos/_shared/`：NixOS 共享硬件/磁盘模板
- `hosts/darwin/<host>/`：每台 macOS 主机配置
- `hosts/outputs/`：flake 输出聚合层
- `nix/modules/`：共享系统模块
- `nix/home/`：共享 Home Manager 配置
- `scripts/`：安装、密钥、主机发现等脚本
- `lib/`：Nix 辅助函数（mkNixosHost/mkDarwinHost/scanPaths）
- `secrets/`：加密后的 secrets（可提交）
- `.keys/`：本地私钥（不可提交）

---

## 7. Binary Cache

当前配置了 3 个二进制缓存（减少本地编译时间）：

- `https://nix-community.cachix.org`
- `https://nixpkgs-wayland.cachix.org`
- `https://cache.garnix.io`

配置位置：`hosts/outputs/default.nix` 中的 `binaryCaches`。

---

## 8. 进阶入口

- 想按环境执行：看 `ENV-USAGE.md`
- 想查命令：看 `NIX-COMMANDS.md`
- 想新增主机：看 `hosts/README.md`
