# 多环境使用手册

按 3 种环境拆分：Live ISO / 已安装 NixOS / macOS。本文档只保留环境差异和手动恢复流程；通用日常命令见 `docs/README.md`。

---

## 通用约定

- 已安装系统的推荐仓库路径：`/persistent/nixos-config`
- Live ISO / 临时环境可直接在任意可写目录使用当前 checkout，例如 `~/nixos`

主机解析来源：
1. 显式指定（`just host=xxx` / `just darwin_host=xxx`）
2. 环境变量（`NIXOS_HOST` / `DARWIN_HOST`）
3. 当前 hostname（由 `resolve-host.sh`）

注意：当前 `justfile` 默认 `host := ""`、`darwin_host := ""`，所以 `just switch/check/test` 与 `just darwin-switch/darwin-check` 未显式指定时都会自动检测当前主机。

主账号开发环境约定：
- Linux/macOS 的语言工具链默认由 Home Manager 提供
- system layer 仅保留桌面运行基线与系统服务
- 可用 `just packages` 同时查看 `environment.systemPackages` 与主用户 `home.packages`

---

## 1. Live ISO（安装 NixOS）

### 启用 flakes

```bash
export NIX_CONFIG="experimental-features = nix-command flakes"
```

### 安装

```bash
nix shell nixpkgs#just -c just hosts
nix shell nixpkgs#just -c just host=zly install-check
nix shell nixpkgs#just -c just host=zly disk=/dev/nvme0n1 install
```

或直接调用脚本（无需 just）：

```bash
REPO="$PWD"
"$REPO"/nix/scripts/admin/install-live.sh --host zky --disk /dev/nvme0n1 --repo "$REPO"
```

说明：交互执行时脚本会再次确认目标磁盘；若在自动化环境中使用，需要显式传 `--yes`。

### 完全手动安装（ISO，不使用 `just install`）

> 危险：以下命令会重分区并清空目标磁盘。执行前务必确认 `DISK`。
> 优先使用 `just install` 或 `install-live.sh`；以下流程仅用于调试或恢复。

当前仓库的 NixOS 磁盘布局（由 `disko` 定义）为：
- GPT + `ESP`（`512M`，`vfat`，挂载 `/boot`）
- 其余空间为 `LUKS2`（`argon2id`，映射名 `crypted-nixos`）
- LUKS 内 `btrfs` 子卷：`@root`、`@nix`、`@persistent`、`@home`、`@swap` 等
- 运行时 `/` 由 `tmpfs` 提供，持久数据写入 `/persistent`

占位符示例（可按你的机器替换）：
- `HOST=zly`（示例主机；可换成 `zky`/`zzly`）
- `DISK=/dev/nvme0n1`（示例目标盘；SATA 常见为 `/dev/sda`）
- `KEY_SRC=/run/media/nixos/USB/main.agekey`（示例 U 盘路径）

```bash
# 0) 准备变量
export NIX_CONFIG="experimental-features = nix-command flakes"
REPO="$PWD"
HOST=zly
DISK=/dev/nvme0n1
KEY_SRC=/run/media/nixos/USB/main.agekey

# 1) 检查主机是否存在，并确认目标磁盘
cd "$REPO"
nix eval "path:$REPO#nixosConfigurations" --apply builtins.attrNames
lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS

# 2) 准备 age 私钥（必须是 AGE-SECRET-KEY-*）
install -D -m 0400 "$KEY_SRC" "$REPO/.keys/main.agekey"
head -n1 "$REPO/.keys/main.agekey"

# 3) 执行分区 + LUKS + 文件系统创建（会提示输入 LUKS 口令）
DISKO_SCRIPT="$(env NIXOS_DISK_DEVICE="$DISK" nix build --impure --no-link --print-out-paths "path:$REPO#nixosConfigurations.$HOST.config.system.build.diskoScript")"
sudo env NIXOS_DISK_DEVICE="$DISK" "$DISKO_SCRIPT"

# 4) 确认挂载结果
findmnt /mnt/boot
findmnt /mnt/persistent
findmnt /mnt/nix
findmnt /mnt/home

# 5) 将 sops 私钥放入目标系统持久目录
sudo install -D -m 0400 -o root -g root "$REPO/.keys/main.agekey" /mnt/persistent/keys/main.agekey

# 6) 安装系统
sudo env NIXOS_DISK_DEVICE="$DISK" nixos-install --impure --flake "path:$REPO#$HOST"

# 7) 同步仓库到目标系统，并保留 .keys/main.agekey
TARGET=/mnt/persistent/nixos-config
TMP="${TARGET}.tmp.$$"
sudo rm -rf "$TMP"
sudo mkdir -p "$TMP"
sudo cp -a "$REPO/." "$TMP/"
sudo install -D -m 0400 -o root -g root "$REPO/.keys/main.agekey" "$TMP/.keys/main.agekey"
OWNER="$(sudo awk -F: '$3 >= 1000 && $3 < 60000 {print $3 \":\" $4; exit}' /mnt/etc/passwd || true)"
[ -n "$OWNER" ] || OWNER="1000:1000"
sudo chown -R "$OWNER" "$TMP"
sudo rm -rf "$TARGET"
sudo mv "$TMP" "$TARGET"

# 8) 将目标系统 /etc/nixos 指向持久仓库并做干跑验证
sudo rm -rf /mnt/etc/nixos
sudo ln -sfn /persistent/nixos-config /mnt/etc/nixos
sudo nixos-rebuild dry-build --flake /mnt/persistent/nixos-config#"$HOST"

# 9) 重启后切换
sudo reboot
# reboot 后:
# cd /persistent/nixos-config && just host="$HOST" switch
```

### 密钥搜索路径

`./.keys/main.agekey` → `<repo>/.keys/main.agekey` → `~/.keys/main.agekey`（需为 `AGE-SECRET-KEY-*` 私钥）

---

## 2. 已安装 NixOS

常规 `check/test/switch`、最小验证与仓库级检查请直接参考 `docs/README.md`。

这里仅保留环境特有操作，例如回滚与清理：

```bash
just rollback
just clean
```

---

## 3. macOS（nix-darwin）

常规 `darwin-check` / `darwin-switch` 用法见 `docs/README.md`。

Flake apps：

```bash
nix run .#build-switch
DARWIN_HOST=zly-mac nix run .#build-switch
```

---

## 4. 常见报错

| 报错 | 处理 |
|------|------|
| `strict mode requires a valid host` | `just hosts` 查看主机，显式指定 `host`/`darwin_host` |
| 找不到 `main.agekey` | 放到 `.keys/main.agekey`（或脚本搜索路径中的其他位置） |
| 密码不生效 | `just password-set-hash '<hash>' && just host=<nixos-host> switch` |
