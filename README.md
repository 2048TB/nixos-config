# NixOS Desktop (Niri + Home Manager)

可复现的 NixOS 桌面配置，基于 Niri Wayland + Home Manager。

相关文档：
- `KEYBINDINGS.md` 快捷键说明（Niri / Tmux / Zellij）
- `NIX-COMMANDS.md` 常用 Nix 命令速查
- `nix/home/README.md` Home 配置结构与说明
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

把两次输出分别填入 `vars/default.nix` 的 `userPasswordHash` 和 `rootPasswordHash`。

2. 安装前构建校验（推荐）

```bash
just install-live-check host=zly
just install-live-check host=zky
```

3. 安装系统（危险：会清空目标盘）

```bash
just install-live host=zly disk=/dev/nvme0n1
# 或
just install-live host=zky disk=/dev/nvme0n1
```

安装完成后：

```bash
just switch host=zly
# 或
just switch host=zky
```

4. macOS（M4 mini）切换配置

```bash
just darwin-check darwin_host=zly-mac
just darwin-switch darwin_host=zly-mac
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

sudo nixos-rebuild switch --flake /etc/nixos#zly
```

---

## 验证流程（推荐）

```bash
just fmt
just lint
just dead
just flake-check
just check

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

主要变量集中在 `vars/default.nix`：
- `username`
- `hostname`
- `gpuMode`（如 `amd-nvidia-hybrid`）
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

GPU 使用 `vars/default.nix` 的 `gpuMode` 固定配置。

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

当前配置使用 `swapfile`，要保证 `systemctl hibernate` 能恢复到原会话，需要设置 `vars/default.nix` 中的 `resumeOffset`。

1. 以 `root` 获取 offset（来自 `btrfs`）：

```bash
sudo btrfs inspect-internal map-swapfile -r /swap/swapfile
```

2. 将输出数字写入 `vars/default.nix` 的 `resumeOffset`。
3. 执行 `just switch` 生效。

注意：
- 如果你重建/迁移了 `/swap/swapfile`，需要重新获取 `resumeOffset`。
- 仅有 `systemctl hibernate` 入口但没有正确 `resumeOffset` 时，可能会“关机但无法恢复会话”。

---

## 目录结构

```
.
├── flake.nix                     # Flake 入口（inputs/nixConfig/outputs）
├── vars/default.nix              # 用户/主机参数（用户名、GPU、密码哈希等）
├── lib/                          # 构建器与辅助函数
│   ├── mkDarwinHost.nix
│   └── mkNixosHost.nix
├── outputs/                      # 多平台 outputs 组装
│   ├── README.md
│   ├── x86_64-linux/default.nix  # Linux 平台聚合（自动发现 src/*.nix）
│   ├── x86_64-linux/src/zly.nix
│   ├── x86_64-linux/src/zky.nix
│   ├── x86_64-linux/tests/{hostname,home}
│   ├── aarch64-darwin/default.nix
│   ├── aarch64-darwin/tests/{hostname,home}
│   └── aarch64-darwin/src/zly-mac.nix
├── hosts/                        # 主机声明
│   ├── README.md
│   ├── nixos/
│   │   ├── default.nix
│   │   ├── zly/{default.nix,disko.nix,hardware.nix,checks.nix}
│   │   └── zky/{default.nix,disko.nix,hardware.nix,checks.nix}
│   └── darwin/
│       ├── default.nix
│       └── zly-mac/{default.nix,home.nix,checks.nix}
├── nix/
│   ├── modules/                  # 系统公共模块
│   └── home/
│       ├── default.nix           # Home 入口（base + linux）
│       ├── base/default.nix      # 跨平台共享 Home 配置
│       ├── linux/default.nix     # Linux Home 配置（Niri/Waybar 等）
│       ├── darwin/default.nix    # Darwin Home 配置模板
│       └── configs/              # 应用配置素材
```
