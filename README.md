# NixOS 多主机配置（新手版）

这是一个可复现的多主机配置仓库：
- Linux 主机：`zly`、`zky`（NixOS + Home Manager）
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
just host=zly install-live-check
# 或目标是另一台
just host=zky install-live-check
```

### 1.5 执行安装（危险，会清盘）

```bash
just host=zly disk=/dev/nvme0n1 install-live
# 或
just host=zky disk=/dev/nvme0n1 install-live
```

### 1.6 重启后第一次切换

```bash
just switch-local
```

---

## 2. 日常更新（已安装 NixOS）

推荐顺序：

```bash
just check-local
just test-local
just switch-local
```

说明：`*-local` 现在是 strict 模式，只接受：
1. `NIXOS_HOST`（显式指定）
2. 当前 hostname（可在仓库中匹配）

如果你要指定主机：

```bash
just host=zly switch
just host=zky switch
```

---

## 3. macOS（nix-darwin）

在 macOS 主机执行：

```bash
just darwin-check-local
just darwin-switch-local
```

说明：Darwin 的 `*-local` 同样是 strict 模式；主机名不匹配时请先设置 `DARWIN_HOST`。

或显式指定：

```bash
just darwin_host=zly-mac darwin-check
just darwin_host=zly-mac darwin-switch
```

补充：`nix run .#build` / `.#build-switch` / `.#apply` 也使用 strict 主机解析（环境变量或当前 hostname）。

---

## 4. 常见问题（新手高频）

### Q1: `strict mode requires a valid host` 是什么？

你在 strict 模式运行了命令，但 hostname 或环境变量没有匹配到仓库里的主机。

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
just switch-local
```

### Q3: 安装时报找不到 `main.agekey`

把私钥放到 `<repo-root>/.keys/main.agekey`，再重试安装命令。

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
- `hosts/darwin/<host>/`：每台 macOS 主机配置
- `nix/modules/`：共享系统模块
- `nix/home/`：共享 Home Manager 配置
- `secrets/`：加密后的 secrets（可提交）
- `.keys/`：本地私钥（不可提交）

---

## 7. 进阶入口

- 想按环境执行：看 `ENV-USAGE.md`
- 想查命令：看 `NIX-COMMANDS.md`
- 想新增主机：看 `hosts/README.md`
