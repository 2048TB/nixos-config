# 多环境使用说明（ISO / NixOS / macOS）

本文档说明在三种环境下如何使用本仓库：

1. NixOS Live ISO 环境（安装系统）
2. 已安装的 NixOS 环境（日常维护）
3. macOS 环境（nix-darwin）

---

## 0. 通用约定

### 0.1 仓库路径

- NixOS 主机推荐仓库路径：`/persistent/nixos-config`
- 你也可以使用任意路径；若不是默认路径，可通过：
  - `NIXOS_CONFIG_REPO=/your/path`
  - 或在 `just` 命令中覆写 `repo=/your/path`

### 0.2 主机解析规则

普通模式（`switch-local` / `check-local` / `test-local`）：

1. `NIXOS_HOST` / `DARWIN_HOST`
2. 当前系统 hostname
3. 默认回退主机（默认不可用时自动选择仓库内首个可用主机）

严格模式（危险操作）：

- `install-live-check-local` / `install-live-local`
- `nix run .#apply` / `nix run .#build-switch` / `nix run .#install`
- 严格模式下：只允许环境变量或 hostname 命中，未命中直接失败，不做 fallback

### 0.3 常用入口

```bash
just hosts
just hooks-enable
just agenix-init
just agenix-init-create
just agenix-recovery-init
just switch-local
just check-local
just test-local
```

---

## 1. 在 ISO 环境使用（安装 NixOS）

### 1.1 前提准备

1. 进入 Live ISO，确保网络可用。
2. 准备 U 盘目录（推荐，保持扁平）：

```text
/USB/
  nixos-config/
    .keys/
      main.agekey
      github_id_ed25519       # 可选（仅用于加密后写入 secrets）
      github_id_ed25519.pub   # 可选（仅用于加密后写入 secrets）
```

说明：

- `nixos-config/` 是本仓库配置目录。
- `.keys/` 是本地密钥目录（建议放在 U 盘里的仓库目录中，不提交到 Git）。
- 执行 `install-live` 时会自动导入：
  - `nixos-config/.keys/main.agekey` -> `/mnt/persistent/keys/main.agekey`（`0400 root:root`）
- 若希望把 GitHub SSH key 也加密托管，先执行：

```bash
just ssh-key-set
```

会生成 `secrets/ssh/github_id_ed25519(.pub).age`，系统在激活时自动放到 `~/.ssh/id_ed25519(.pub)`。

若要启用多 recipient（主密钥 + recovery + 主机 SSH host key）：

```bash
just agenix-recovery-init
just agenix-host-key-add zly /etc/ssh/ssh_host_ed25519_key.pub
just agenix-rekey
```

3. 克隆仓库（或直接进入 U 盘中的 `nixos-config` 目录）：

```bash
git clone https://github.com/2048TB/nixos.git ~/nixos
cd ~/nixos
```

4. 查看可用主机：

```bash
just hosts
```

5. 设置目标主机密码哈希（必须）：

```bash
just password-hashes
```

把目标 hash 写入 agenix（user/root 同步）：

```bash
just password-set-hash '<sha512-hash>'
```

说明：仓库设置了 `users.mutableUsers = false`，密码应通过 agenix secrets 维护；直接 `passwd` 在后续 rebuild 后会被声明式配置覆盖。

### 1.2 安装前检查

显式指定主机：

```bash
just host=zly install-live-check
just host=zky install-live-check
```

自动按本机 hostname（严格模式）：

```bash
just install-live-check-local
```

### 1.3 执行安装（危险）

显式指定主机和磁盘：

```bash
just host=zly disk=/dev/nvme0n1 install-live
```

自动按 hostname（严格模式）：

```bash
just disk=/dev/nvme0n1 install-live-local
```

说明：

- `install-live` 会清空目标盘并执行分区/格式化。
- 当前实现会使用仓库锁定输入生成 `diskoScript`，并在复制仓库时优先 `rsync --exclude .git`。
- `<repo-root>/.keys/main.agekey` 为必需项，`install-live` 会自动导入为 `/mnt/persistent/keys/main.agekey`，缺失会直接失败。
- `just agenix-init` 默认不会创建新主密钥；首次初始化需用 `just agenix-init-create`。
- GitHub SSH key 由 agenix secrets 在系统激活阶段下发（若 `secrets/ssh/github_id_ed25519(.pub).age` 存在）。

### 1.4 安装后

重启进入系统后执行：

```bash
just switch-local
```

如果需要显式指定：

```bash
just host=zly switch
```

---

## 2. 在已安装 NixOS 环境使用（日常）

### 2.1 日常更新流程（推荐）

```bash
just check-local
just test-local
just switch-local
```

### 2.2 显式指定主机

```bash
just host=zly check
just host=zly switch
just host=zky check
just host=zky switch
```

### 2.3 回归与质量检查

```bash
just eval-tests
just flake-check
just fmt
just lint
just dead
```

### 2.4 维护与回滚

```bash
just rollback
just clean
just clean-all
```

### 2.5 新增主机

```bash
just new-nixos-host devbox
just new-nixos-host-dry-run devbox
just new-nixos-host-force devbox
```

新增后建议：

```bash
just hosts
just eval-tests
just host=devbox check
```

---

## 3. 在 macOS 环境使用（nix-darwin）

### 3.1 前提

1. 已安装 Nix。
2. 已具备 `darwin-rebuild`（通过本仓库 flake 配置的 nix-darwin）。
3. 克隆仓库并进入目录。

### 3.2 常用命令

自动按 hostname：

```bash
just darwin-check-local
just darwin-switch-local
```

显式指定主机：

```bash
just darwin_host=zly-mac darwin-check
just darwin_host=zly-mac darwin-switch
```

查看主机列表：

```bash
just darwin-hosts
```

### 3.3 Flake apps 方式

```bash
nix run .#build
nix run .#build-switch
DARWIN_HOST=zly-mac nix run .#build-switch
```

说明：

- `nix run .#apply` / `.#build-switch` 使用 strict 主机解析。
- 如果 hostname 不匹配且未设置 `DARWIN_HOST`，命令会直接失败。

---

## 4. 常见问题（FAQ）

### 4.1 `strict mode requires a valid host...`

原因：严格模式下未命中主机。

处理：

1. 检查当前 hostname 是否与仓库主机名一致（如 `zly` / `zky` / `zly-mac`）。
2. 或显式设置环境变量：
   - `NIXOS_HOST=zly ...`
   - `DARWIN_HOST=zly-mac ...`

### 4.2 自动解析到了错误主机

先看当前主机名与环境变量：

```bash
hostname
echo "$NIXOS_HOST"
echo "$DARWIN_HOST"
```

再用显式主机运行命令。

### 4.3 安装时目标磁盘不对

务必显式传入：

```bash
just host=zly disk=/dev/your-disk install-live
```

安装前先确认设备名（`lsblk` / `fdisk -l`）。

### 4.4 在 Linux 上执行 Darwin build 失败

`darwin-check` 需要 macOS 主机执行，或具备 `aarch64-darwin` remote builder。

---

## 5. 快速命令总览

```bash
# ISO 安装
just install-live-check-local
just disk=/dev/nvme0n1 install-live-local

# NixOS 日常
just check-local
just switch-local

# macOS 日常
just darwin-check-local
just darwin-switch-local
```
