# NixOS Desktop (Niri + Home Manager)

可复现的 NixOS 桌面配置，基于 Niri Wayland + Home Manager。

相关文档：
- `KEYBINDINGS.md` 快捷键说明（Niri / Tmux / Zellij）
- `NIX-COMMANDS.md` 常用 Nix 命令速查
- `nix/home/README.md` Home 配置结构与说明
- `apps/README.md` flake apps 命令入口说明
- `AGENTS.md` 贡献与协作约定
- `justfile` 日常操作命令
- `CLAUDE.md` 项目维护约定（给 AI/自动化工具）

主要特性：
- Wayland 桌面：Niri + Waybar + Fuzzel + Wlogout
- 窗口管理：Niri scrollable-tiling + 动态工作区（见 `KEYBINDINGS.md`）
- 终端复用器：Tmux / Zellij 统一使用 `Ctrl + B` 作为 leader/prefix（见 `KEYBINDINGS.md`）
- X11 兼容：`xwayland-satellite`（Niri 官方推荐路径）
- Waybar 状态栏：`niri/workspaces` + `niri/window` + `mpris` + `cpu/memory/temperature/public-ip/backlight/battery/tray/notification`
- 开发工具链：Rust / Zig / Go / Node.js / Python
- 游戏支持：Steam / Proton / Wine / Lutris
- 中文输入：Fcitx5
- 存储：tmpfs 根分区 + Btrfs + LUKS + preservation 持久化
- 安全：AppArmor（可选 Secure Boot）

---

## 快速开始

推荐方式（统一命令入口，在 Live ISO 中）：

```bash
git clone https://github.com/2048TB/nixos.git ~/nixos
cd ~/nixos
```

1. 设置密码哈希（必须）

```bash
mkpasswd -m sha-512
mkpasswd -m sha-512
```

把两次输出分别填入目标主机的 `hosts/nixos/<host>/vars.nix`（`userPasswordHash` / `rootPasswordHash`）。

2. 安装前构建校验（推荐）

```bash
just host=zly install-live-check
just host=zky install-live-check
```

3. 安装系统（危险：会清空目标盘）

```bash
just host=zly disk=/dev/nvme0n1 install-live
# 或
just host=zky disk=/dev/nvme0n1 install-live
```

安装完成后：

```bash
# 显式指定主机
just host=zly switch
just host=zky switch

# 或自动按当前 hostname 匹配（推荐）
just switch-local
```

4. macOS（M4 mini）切换配置

```bash
just darwin_host=zly-mac darwin-check
just darwin_host=zly-mac darwin-switch

# 或自动按当前 hostname 匹配（推荐）
just darwin-check-local
just darwin-switch-local
```

说明：`darwin-check` 需要在 macOS 主机执行，或在 Linux 上配置 `aarch64-darwin` remote builder 后执行。

5. 可选：使用 flake apps 管理（参考仓库方式）

```bash
# 默认自动按当前 hostname 解析主机
nix run .#build
nix run .#build-switch
nix run .#install

# 指定主机
NIXOS_HOST=zky nix run .#build-switch
DARWIN_HOST=zly-mac nix run .#build-switch
```

说明：`/etc/nixos` 是指向 `/persistent/nixos-config` 的符号链接。
这意味着：
1. `/etc/nixos` 只是入口，兼容传统用法与工具习惯。
2. 真实仓库在 `/persistent/nixos-config`（持久化盘），避免 `/` 为 tmpfs 时丢失配置。
3. 编辑 `/etc/nixos` 等同于编辑 `/persistent/nixos-config`。
4. symlink 的创建依赖 `/persistent` 在早期启动阶段已挂载；当前已设置 `fileSystems."/persistent".neededForBoot = true`。
5. 如果你将来修改 disko 布局（改名/移除 `/persistent` 子卷），必须同步调整：disko 配置中的挂载点、`fileSystems."/persistent"` 以及 `tmpfiles` 规则（`/etc/nixos` symlink）。

如不使用 `just`，等价的底层命令如下：

```bash
sudo env NIXOS_DISK_DEVICE=/dev/nvme0n1 \
  nix --extra-experimental-features "nix-command flakes" \
  run github:nix-community/disko -- --mode disko --flake .#zly

findmnt /mnt/boot
findmnt /mnt/persistent

sudo rm -rf /mnt/persistent/nixos-config
sudo mkdir -p /mnt/persistent/nixos-config
sudo cp -a ./. /mnt/persistent/nixos-config/

sudo env NIXOS_DISK_DEVICE=/dev/nvme0n1 \
  nixos-install --impure --flake /mnt/persistent/nixos-config#zly

sudo nixos-rebuild switch --flake path:/persistent/nixos-config#zly
```

---

## 验证流程（推荐）

```bash
just fmt
just lint
just dead
just flake-check
just check
just eval-tests

# 可选：完整系统构建验证（不切换）
nix build --no-link path:/persistent/nixos-config#nixosConfigurations.zly.config.system.build.toplevel
```

---

## 日志排查（Niri/Waybar）

```bash
journalctl --user -b -u waybar.service -u xdg-desktop-portal.service --no-pager
journalctl --user -b --no-pager | rg -i 'niri|waybar|portal|pipewire|wireplumber|swaync'
```

说明：当前配置已在 `nix/modules/system.nix` 中对 `pipewire` 与 `pipewire-pulse` 同步关闭 `rtportal.enabled`，用于减少 `xdg-desktop-portal` 的 `pidns/pidfd` 噪音日志。

---

## 同步到 GitHub

```bash
git status
git add -A
git commit -m "docs: refresh repository documentation"
git push origin HEAD
```

---

## 配置入口

NixOS 主机变量集中在各自的 `hosts/nixos/<host>/vars.nix`：
- `username`
- `hostname`
- `gpuMode`（如 `amd-nvidia-hybrid`）
- `roles`（如 `["desktop" "container"]`，控制 Steam/VPN/libvirt/docker/flatpak 默认开关）
- `swapSizeGb`
- `resumeOffset`（hibernate 恢复偏移，swapfile 场景）
- `userPasswordHash`
- `rootPasswordHash`

---

## 主题统一策略

当前配置使用「全局暗色 + 分层覆盖」：
- GTK：`dconf.settings` 统一 `prefer-dark` + `Adwaita-dark`
- Qt6：`qt6ct` 使用 `darker.conf`
- Wayland 组件（Niri / Waybar / Fuzzel / Wlogout / Foot / Ghostty）：统一到深色调（Catppuccin 风格）

说明：
- 浏览器与 Electron 类应用（如 Chrome、VS Code）通常需要应用内单独选择主题，无法仅靠 GTK/Qt 全局主题强制统一。

---

## Shell 快捷命令

`zsh` 中内置以下快捷函数（见 `nix/home/configs/shell/zshrc`）：
- `ccv` / `ccv r`：Claude Code 快捷启动与恢复
- `cdx` / `cdx r`：Codex 快捷启动与恢复

---

## GPU 选择

GPU 使用对应主机 `hosts/nixos/<host>/vars.nix` 的 `gpuMode` 固定配置。

---

## 磁盘布局（默认）

```
/dev/nvme0n1
├── nvme0n1p1  EFI (512MB, FAT32)
└── nvme0n1p2  LUKS
    └── crypted-nixos (Btrfs)
        ├── @root       → tmpfs
        ├── @nix        → /nix
        ├── @persistent → /persistent
        ├── @home       → /home
        ├── @swap       → /swap (swapfile)
        ├── @snapshots  → /snapshots
        └── @tmp        → /tmp
```

---

## Hibernate（休眠恢复）

当前配置使用 `swapfile`，要保证 `systemctl hibernate` 能恢复到原会话，需要设置对应主机 `hosts/nixos/<host>/vars.nix` 中的 `resumeOffset`。

1. 以 `root` 获取 offset（来自 `btrfs`）：

```bash
sudo btrfs inspect-internal map-swapfile -r /swap/swapfile
```

2. 将输出数字写入对应主机 `hosts/nixos/<host>/vars.nix` 的 `resumeOffset`。
3. 执行 `just switch` 生效。

注意：
- 如果你重建/迁移了 `/swap/swapfile`，需要重新获取 `resumeOffset`。
- 仅有 `systemctl hibernate` 入口但没有正确 `resumeOffset` 时，可能会“关机但无法恢复会话”。

---

## 目录结构

```
.
├── flake.nix                     # Flake 入口（inputs/nixConfig/outputs）
├── apps/                         # flake app 使用说明
├── lib/                          # 构建器与辅助函数
│   ├── default.nix               # lib 聚合入口（system/host 构建函数）
│   ├── mkDarwinHost.nix
│   └── mkNixosHost.nix
├── hosts/                        # 主机相关统一收敛
│   ├── README.md
│   ├── outputs/                  # 多平台 outputs 组装
│   │   ├── README.md
│   │   ├── default.nix
│   │   ├── x86_64-linux/{default.nix,tests/{hostname,home}}
│   │   └── aarch64-darwin/{default.nix,tests/{hostname,home}}
│   ├── nixos/
│   │   ├── zly/{disko.nix,hardware.nix,vars.nix,home.nix,checks.nix}
│   │   └── zky/{disko.nix,hardware.nix,vars.nix,home.nix,checks.nix}
│   └── darwin/
│       └── zly-mac/{default.nix,vars.nix,home.nix,checks.nix}
├── nix/
│   ├── modules/                  # 系统公共模块
│   └── home/
│       ├── base/default.nix      # 跨平台共享 Home 配置
│       ├── linux/default.nix     # Linux Home 配置（Niri/Waybar 等）
│       ├── darwin/default.nix    # Darwin Home 配置模板
│       └── configs/              # 应用配置素材
├── scripts/
│   ├── resolve-host.sh           # 按 hostname 自动解析主机
│   └── new-host.sh               # 生成 NixOS/Darwin 主机目录脚手架
```

---

## 新增主机（自动发现）

新增主机不再需要修改 `hosts/outputs/<system>/default.nix`，只需新增 `hosts` 目录：

1. 用脚手架命令生成主机目录（推荐）：

```bash
# 从现有模板主机复制（默认 from=zly / zly-mac）
just new-nixos-host <host>
just new-darwin-host <host>

# 或指定来源模板主机
just new-nixos-host <host> <from-host>
just new-darwin-host <host> <from-host>
```

2. 按需调整新主机 `vars.nix` / `disko.nix` / `hardware.nix` / `home.nix`。
3. NixOS 必需：在 `vars.nix` 中填写完整主机变量（例如 `gpuMode`、`resumeOffset`、密码哈希等）。
4. Darwin 必需：在 `vars.nix` 中至少填写 `username`（可按需扩展）。
5. 验证自动发现：

```bash
just hosts
just eval-tests
```

---

## 主机目录约定（zly / zky）

- `zly` 与 `zky` 保持“结构一致、文件独立”的维护方式。
- 即使当前内容相同，也优先保留各自 `vars.nix` / `hardware.nix` / `disko.nix` / `checks.nix` / `home.nix`。
- 这样后续出现硬件差异或策略差异时，可以直接在各自主机目录演进，无需再拆分共享层。
