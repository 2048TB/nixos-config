# 多环境使用手册

只写环境差异：Live ISO / 已安装 NixOS / 其他环境中的只读 flake 操作。通用安装和 secrets 流程见 `docs/README.md`，命令速查见 `docs/NIX-COMMANDS.md`。

---

## 通用约定

- 已安装系统的推荐仓库路径：`/persistent/nixos-config`
- Live ISO / 临时环境可直接在任意可写目录使用当前 checkout，例如 `~/nixos`
- 本文不重复命令总表；需要完整命令列表时看 `docs/NIX-COMMANDS.md`

---

## 1. Live ISO（安装 NixOS）

### 开始前先确认

对新手，建议先回到仓库根目录再执行安装命令：

```bash
cd ~/nixos
pwd
```

安装前至少确认这 4 件事：
- 当前目录就是仓库根目录，且其中有 `flake.nix`
- 目标 `host` 已存在于当前仓库，例如 `zly`
- 你已经确认目标磁盘设备名，避免误清盘
- 你手里有可用的 `main.agekey`，或已按 `docs/README.md` 完成首次初始化

如果你还没完成仓库获取、密码 hash / sops 初始化，先按 `docs/README.md` 的“首次安装（Live ISO）”完整走一遍，再回到本节看环境差异。

### 启用 flakes

```bash
export NIX_CONFIG="experimental-features = nix-command flakes"
```

### 最短可复制流程（推荐）

如果你是第一次装机，先用脚本版，不要先走手动版：

```bash
cd ~/nixos
export NIX_CONFIG="experimental-features = nix-command flakes"
lsblk -o NAME,SIZE,MODEL,TYPE,MOUNTPOINTS
nix shell nixpkgs#just -c just host=zly disk=/dev/nvme0n1 install
```

其中：
- `host=zly` 要换成你要安装的主机名
- `disk=/dev/nvme0n1` 要换成你真正要清空的磁盘

### 安装方式一：使用安装脚本（推荐）

先确认磁盘设备名，推荐至少看一次：

```bash
lsblk -o NAME,SIZE,MODEL,TYPE,MOUNTPOINTS
```

例如常见磁盘名可能是：
- NVMe：`/dev/nvme0n1`
- SATA / USB：`/dev/sda`

通过 `just` 调用：

```bash
nix shell nixpkgs#just -c just host=zly disk=/dev/nvme0n1 install
```

等价的直接脚本调用：

```bash
REPO="$PWD"
bash "$REPO/nix/scripts/admin/install-live.sh" --host zly --disk /dev/nvme0n1 --repo "$REPO"
```

说明：
- Live ISO 通常需要先显式开启 flakes
- 脚本会再次确认目标磁盘；自动化环境中需要显式传 `--yes`
- `--repo` 若显式传错会直接失败，不会静默回退到当前 checkout
- `host=` 必须是仓库里已有的主机名，不会自动猜测
- 安装命令会调用 `disko` 清空目标盘，请先确认 `disk=` 无误

### 安装方式二：不使用安装脚本（手动）

只有在你明确想逐步控制流程时再走这一版。下面命令默认你当前就在仓库根目录：

```bash
cd ~/nixos
export NIX_CONFIG="experimental-features = nix-command flakes"
REPO="$PWD"
HOST="zly"
DISK="/dev/nvme0n1"
KEY_SRC="$REPO/.keys/main.agekey"
flake_repo="$(bash "$REPO/nix/scripts/admin/print-flake-repo.sh" "$REPO")"
```

1. 先确认主机名和磁盘值已经改成你自己的：

```bash
printf 'HOST=%s\nDISK=%s\nREPO=%s\nKEY_SRC=%s\n' "$HOST" "$DISK" "$REPO" "$KEY_SRC"
lsblk -o NAME,SIZE,MODEL,TYPE,MOUNTPOINTS
```

2. 生成并执行 `disko` 脚本：

```bash
disko_script="$(env NIXOS_DISK_DEVICE="$DISK" nix build --impure --no-link --print-out-paths "path:${flake_repo}#nixosConfigurations.${HOST}.config.system.build.diskoScript")"
echo "$disko_script"
sudo env NIXOS_DISK_DEVICE="$DISK" "$disko_script"
```

3. 确认目标分区已经挂载：

```bash
findmnt /mnt/boot
findmnt /mnt/persistent
```

4. 安装 `main.agekey` 到目标系统。
如果 key 在仓库里：

```bash
sudo install -D -m 0400 -o root -g root "$KEY_SRC" /mnt/persistent/keys/main.agekey
```

如果 key 不在仓库里，把前面的 `KEY_SRC` 改成真实路径，例如：

```bash
KEY_SRC="$HOME/.keys/main.agekey"
```

5. 执行 `nixos-install`：

```bash
sudo env NIXOS_DISK_DEVICE="$DISK" nixos-install --impure --flake "path:${flake_repo}#${HOST}"
```

6. 把当前仓库同步到目标系统的持久化目录：

```bash
TARGET_FLAKE_DIR="/mnt/persistent/nixos-config"
TARGET_FLAKE_TMP="${TARGET_FLAKE_DIR}.tmp.$$"

sudo rm -rf "$TARGET_FLAKE_TMP"
sudo mkdir -p "$TARGET_FLAKE_TMP"
sudo cp -a "$REPO/." "$TARGET_FLAKE_TMP/"
sudo install -D -m 0400 -o root -g root "$KEY_SRC" "$TARGET_FLAKE_TMP/.keys/main.agekey"
```

7. 把目标仓库 owner 改成目标系统主用户：

```bash
target_user="$(nix eval --raw "path:${flake_repo}#nixosConfigurations.${HOST}.config.my.host.username")"
target_uid="$(awk -F: -v user="$target_user" '$1 == user { print $3; exit }' /mnt/etc/passwd)"
target_gid="$(awk -F: -v user="$target_user" '$1 == user { print $4; exit }' /mnt/etc/passwd)"
sudo chown -R "${target_uid}:${target_gid}" "$TARGET_FLAKE_TMP"
sudo rm -rf "$TARGET_FLAKE_DIR"
sudo mv "$TARGET_FLAKE_TMP" "$TARGET_FLAKE_DIR"
```

8. 让目标系统的 `/etc/nixos` 指向持久化仓库：

```bash
sudo rm -rf /mnt/etc/nixos
sudo ln -sfn /persistent/nixos-config /mnt/etc/nixos
```

9. 做一次 dry-build 验证：

```bash
sudo nixos-rebuild dry-build --flake /mnt/persistent/nixos-config#"$HOST"
```

手动版和脚本版的目标相同：
- 清盘并分区
- 安装系统
- 写入 `/persistent/keys/main.agekey`
- 同步仓库到 `/persistent/nixos-config`
- 让 `/etc/nixos` 指向持久化仓库

### 密钥搜索路径

`./.keys/main.agekey` → `<repo>/.keys/main.agekey` → `~/.keys/main.agekey`

补充：
- `install-live.sh` 安装时必须能找到可读、有效的 `main.agekey`
- 找不到 key 时，安装会在写入系统前直接失败
- 安装成功后，脚本会把该 key 放到目标系统的 `/persistent/keys/main.agekey`
- 如果走手动版，你也必须自己完成这一步，否则目标系统里的 sops secrets 无法解密

### 安装完成后

脚本成功结束前还会执行这些动作：
- 把仓库同步到目标系统的 `/persistent/nixos-config`
- 把目标系统的 `/etc/nixos` 链接到 `/persistent/nixos-config`
- 对目标主机做一次 `nixos-rebuild dry-build`

看到 `done: reboot into the installed system` 后，再移除安装介质并重启进入新系统。

---

## 2. 已安装 NixOS

已安装系统上的差异主要是：通常直接在 `/persistent/nixos-config` 做 lock、rebuild、secrets 维护。

1. 更新 lock：

```bash
just update
just update-nixpkgs
```

2. build / check / switch：

```bash
just host=zly build
just host=zly check
just host=zly dry-build
just host=zly switch
just host=zly boot
just host=zly test
```

3. 清理与维护：

```bash
just clean
just clean-all
just optimize
just gc
just use
```

4. 维护 secrets：

```bash
just sops-recipients
just sops-rekey
```

也可以从任意目录直接调用：

```bash
bash /persistent/nixos-config/nix/scripts/admin/sops.sh recipients
bash /persistent/nixos-config/nix/scripts/admin/guard-secrets.sh
```

---

## 3. 其他环境中的只读 flake 操作

如果 checkout 中存在不可读的 `.keys/main.agekey`，不要直接对原始 repo 执行：

```bash
nix eval path:/persistent/nixos-config#...
```

先取 filtered repo：

```bash
REPO=/persistent/nixos-config
flake_repo="$(bash "$REPO/nix/scripts/admin/print-flake-repo.sh" "$REPO")"
nix flake show "path:$flake_repo"
nix eval "path:$flake_repo#nixosConfigurations" --apply builtins.attrNames
```

---

## 4. 常见报错

| 报错 | 处理 |
|------|------|
| `path:<repo>` 评估时报 `.keys/main.agekey: Permission denied` | 先调用 `print-flake-repo.sh` 获取 filtered repo |
| `just update` 报 `.keys/main.agekey: Permission denied` | 现在应改为走 `update-flake.sh`；若仍失败，检查仓库根目录和 `flake.lock` 是否可写 |
| 找不到 `main.agekey` | 放到 `.keys/main.agekey`（或脚本搜索路径中的其他位置） |
| 显式传了错误的 `--repo` / `NIXOS_CONFIG_REPO` | 当前脚本会直接报错退出；修正路径后重试 |
