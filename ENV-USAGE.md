# 多环境使用手册（新手版）

本文按 3 种环境拆开：
1. NixOS Live ISO（安装系统）
2. 已安装 NixOS（日常维护）
3. macOS（nix-darwin）

如果你不确定看哪段：
- 正在装系统：看第 1 章
- 系统已经装好：看第 2 章
- 你在 Mac 上：看第 3 章

---

## 通用约定

推荐仓库路径：`/persistent/nixos-config`

主机自动识别优先级：
1. 环境变量（`NIXOS_HOST` / `DARWIN_HOST`）
2. 当前系统 hostname
3. fallback（仅普通模式允许）

strict 模式（危险命令）不允许 fallback：
- `install-live-check-local`
- `install-live-local`
- `nix run .#apply` / `.#build-switch` / `.#install`

---

## 1. Live ISO 环境（安装 NixOS）

### 1.1 最小步骤（推荐按顺序）

```bash
git clone https://github.com/2048TB/nixos.git ~/nixos
cd ~/nixos
just hooks-enable
```

### 1.2 密钥准备

情况 A：你是第一次部署（没有旧密钥）

```bash
just agenix-init-create
just agenix-recovery-init
```

情况 B：你已有旧密钥（U 盘/旧机器）

1. 把旧的 `main.agekey` 复制到 `./.keys/main.agekey`
2. 执行：

```bash
just agenix-init
```

可选：把 GitHub SSH key 也托管进 agenix

```bash
just ssh-key-set
```

### 1.3 设置登录密码（必须）

```bash
just password-hashes
just password-set-hash '<sha512-hash>'
```

### 1.4 安装前检查

```bash
just host=zly install-live-check
# 或
just host=zky install-live-check
```

### 1.5 执行安装（清盘）

```bash
just host=zly disk=/dev/nvme0n1 install-live
# 或
just host=zky disk=/dev/nvme0n1 install-live
```

### 1.6 安装后第一步

重启进入系统后：

```bash
just switch-local
```

---

## 2. 已安装 NixOS（日常维护）

### 2.1 日常更新推荐流程

```bash
just check-local
just test-local
just switch-local
```

### 2.2 指定主机

```bash
just host=zly check
just host=zly switch
just host=zky check
just host=zky switch
```

### 2.3 质量检查

```bash
just scripts-check
just eval-tests
just flake-check
```

### 2.4 回滚与清理

```bash
just rollback
just clean
just clean-all
```

---

## 3. macOS（nix-darwin）

### 3.1 常用命令

```bash
just darwin-check-local
just darwin-switch-local
```

显式指定主机：

```bash
just darwin_host=zly-mac darwin-check
just darwin_host=zly-mac darwin-switch
```

### 3.2 flake apps 方式

```bash
nix run .#build
nix run .#build-switch
DARWIN_HOST=zly-mac nix run .#build-switch
```

---

## 4. 新手常见报错

### 报错：`strict mode requires a valid host`

处理：

```bash
just hosts
just host=zly <命令>
```

### 报错：找不到 `.keys/main.agekey`

处理：
1. 确认你在仓库根目录
2. 把私钥放到 `./.keys/main.agekey`
3. 重新运行命令

### 报错：密码不生效

处理：

```bash
just password-set-hash '<sha512-hash>'
just switch-local
```

---

## 5. 新手记忆版（只记这几个）

- 安装前检查：`just host=zly install-live-check`
- 安装系统：`just host=zly disk=/dev/nvme0n1 install-live`
- 日常更新：`just check-local && just test-local && just switch-local`
- 查看主机：`just hosts`
