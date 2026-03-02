# hosts 目录说明（新手版）

这个目录决定"每台机器用哪套配置"。

---

## 1. 目录怎么读

- `hosts/nixos/<host>/`：NixOS 主机配置
- `hosts/nixos/_shared/`：NixOS 共享模板（`hardware-common.nix`、`disko-common.nix`、`checks.nix`）
- `hosts/darwin/<host>/`：macOS 主机配置

当前已有主机：
- NixOS：`zly`、`zky`、`zzly`
- Darwin：`zly-mac`

---

## 2. 每个主机目录里什么是必须的

### NixOS 主机（`hosts/nixos/<host>/`）

必须有：
- `hardware.nix`
- `disko.nix`
- `vars.nix`

可选：
- `home.nix`
- `checks.nix`
- `modules/`
- `home-modules/`

### Darwin 主机（`hosts/darwin/<host>/`）

必须有：
- `default.nix`
- `vars.nix`

可选：
- `home.nix`
- `checks.nix`
- `modules/`
- `home-modules/`

---

## 3. 新增主机（推荐命令）

```bash
# 新增 NixOS 主机（默认从 zly 模板复制）
just new-nixos-host devbox

# 新增 Darwin 主机（默认从 zly-mac 模板复制）
just new-darwin-host mac-mini
```

先预览不落盘：

```bash
just new-nixos-host-dry-run devbox
just new-darwin-host-dry-run mac-mini
```

---

## 4. 新增后你要改什么

1. `vars.nix`：主机名、用户名、硬件参数
   常见可调项：`roles`、`dockerMode`（`rootless`/`rootful`）、`enableAggressiveApparmorKill`、`enableWpsOffice`、`enableZathura`、`enableSplayer`、`enableTelegramDesktop`、`enableLocalSend`
2. `disko.nix`：磁盘布局（NixOS）
3. `hardware.nix`：硬件探测结果（NixOS）

---

## 5. 新增后你要验证什么

```bash
just hosts
just eval-tests
just host=devbox check
```

---

## 6. 主机自动检测规则

`just switch` 等日常命令不指定 `host` 时自动检测（strict 模式）：
1. `NIXOS_HOST` / `DARWIN_HOST` 环境变量
2. 当前 hostname
如果 1/2 都不匹配，会直接报错，不再 fallback。

安装命令（`install` / `install-check`）必须显式指定 `host`。

同样规则也适用于 `nix run .#build` / `.#build-switch` / `.#apply`。

---

## 7. 安装后配置目录约定

Live ISO 安装流程会把仓库同步到 `/persistent/nixos-config`，并把 `/etc/nixos` 链接到该路径。  
主目录中的 `~/nixos` 入口默认也指向这个持久化目录。
