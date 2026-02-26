# NixOS Desktop (Hyprland + Home Manager)

可复现的 NixOS 桌面配置，基于 Hyprland Wayland + Home Manager。

相关文档：
- `KEYBINDINGS.md` 快捷键说明
- `NIX-COMMANDS.md` 常用 Nix 命令速查
- `AGENTS.md` 贡献与协作约定
- `justfile` 日常操作命令
- `CLAUDE.md` 项目维护约定（给 AI/自动化工具）

主要特性：
- Wayland 桌面：Hyprland + Waybar + Fuzzel + Wlogout
- 窗口管理：Master 布局 + float/passthrough submap，高频操作以二键绑定为主（见 `KEYBINDINGS.md`）
- Waybar 网络区：`network` + `custom/public-ip` + `custom/wifi-manager`（链路状态、公网 IP、WiFi 管理入口）
- 开发工具链：Rust / Zig / Go / Node.js / Python
- 游戏支持：Steam / Proton / Wine / Lutris
- 中文输入：Fcitx5
- 存储：tmpfs 根分区 + Btrfs + LUKS + preservation 持久化
- 安全：AppArmor（可选 Secure Boot）

---

## 快速开始

推荐方式（在 Live ISO 中）：

```bash
git clone https://github.com/aicode12/nixos.git ~/nixos
cd ~/nixos
```

1. 设置密码哈希（必须）

```bash
mkpasswd -m sha-512
mkpasswd -m sha-512
```

把两次输出分别填入 `flake.nix` 的 `myvars.userPasswordHash` 和 `myvars.rootPasswordHash`。

2. 磁盘分区与挂载（会清空目标磁盘）

```bash
sudo nix --extra-experimental-features nix-command --extra-experimental-features flakes \
  run github:nix-community/disko -- \
  --mode disko --flake .#zly

findmnt /mnt/boot
```

3. 安装系统

```bash
sudo nixos-install --impure --flake .#zly
```

安装完成后：

```bash
sudo nixos-rebuild switch --flake /etc/nixos#zly
```

说明：`/etc/nixos` 是指向 `/persistent/nixos-config` 的符号链接。
这意味着：
1. `/etc/nixos` 只是入口，兼容传统用法与工具习惯。
2. 真实仓库在 `/persistent/nixos-config`（持久化盘），避免 `/` 为 tmpfs 时丢失配置。
3. 编辑 `/etc/nixos` 等同于编辑 `/persistent/nixos-config`。
4. symlink 的创建依赖 `/persistent` 在早期启动阶段已挂载；当前已设置 `fileSystems."/persistent".neededForBoot = true`。
5. 如果你将来修改 disko 布局（改名/移除 `/persistent` 子卷），必须同步调整：disko 配置中的挂载点、`fileSystems."/persistent"` 以及 `tmpfiles` 规则（`/etc/nixos` symlink）。

---

## 安装脚本（Live ISO）

已提供脚本：`scripts/install-live.sh`

```bash
cd ~/nixos
./scripts/install-live.sh
```

默认等价于：
- 自动探测并选择最大非 USB 磁盘
- 固定流程：`预清理挂载/LUKS -> disko -> EFI 挂载检查 -> 交互式修改 LUKS 密码 -> nixos-install -> 同步 flake 到 /mnt/persistent/nixos-config -> dry-build 校验`（高危，会重建分区）
- 无需命令参数
- 可选环境变量：`NIXOS_DISK_DEVICE=/dev/<disk>`（覆盖目标盘）、`DRY_RUN=1`、`CONFIRM=0`

---

## 一键式完整安装命令（Live ISO）

```bash
git clone https://github.com/aicode12/nixos.git ~/nixos
cd ~/nixos

sudo nix --extra-experimental-features "nix-command flakes" \
  run github:nix-community/disko -- --mode disko --flake .#zly

findmnt /mnt/boot

sudo nixos-install --impure --flake .#zly
```

重启后执行：

```bash
sudo nixos-rebuild switch --flake /etc/nixos#zly
```

---

## 配置入口

主要变量集中在 `flake.nix` 的 `myvars`：
- `username`
- `hostname`
- `gpuMode`（如 `amd-nvidia-hybrid`）
- `swapSizeGb`
- `userPasswordHash`
- `rootPasswordHash`

---

## 主题统一策略

当前配置使用「全局暗色 + 分层覆盖」：
- GTK：`dconf.settings` 统一 `prefer-dark` + `Adwaita-dark`
- Qt6：`qt6ct` 使用 `darker.conf`
- Wayland 组件（Hyprland / Waybar / Fuzzel / Wlogout / Foot / Ghostty）：统一到深色调（Catppuccin 风格）

说明：
- 浏览器与 Electron 类应用（如 Chrome、VS Code）通常需要应用内单独选择主题，无法仅靠 GTK/Qt 全局主题强制统一。

---

## Shell 快捷命令

`zsh` 中内置以下快捷函数（见 `nix/home/configs/shell/zshrc`）：
- `ccv` / `ccv r`：Claude Code 快捷启动与恢复
- `cdx` / `cdx r`：Codex 快捷启动与恢复

---

## GPU 选择

GPU 使用 `flake.nix` 的 `myvars.gpuMode` 固定配置。

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

## 目录结构

```
.
├── flake.nix                 # 入口（inputs/outputs/myvars）
├── nix/
│   ├── hosts/                # 主机配置
│   ├── modules/
│   │   ├── system.nix        # 系统配置
│   │   └── hardware.nix      # GPU 驱动
│   └── home/
│       ├── default.nix       # Home Manager 入口
│       └── configs/          # 应用配置
│           ├── niri/         # 旧 Niri 配置（已归档，当前主用 Hyprland）
│           ├── waybar/       # Waybar 状态栏
│           ├── wlogout/      # 电源菜单
│           ├── fuzzel/       # 应用启动器
│           ├── foot/         # Foot 终端
│           ├── ghostty/      # Ghostty 终端
│           ├── hypr/         # Hyprland 配置
│           ├── shell/        # zsh/vim
│           ├── fcitx5/       # 输入法
│           ├── git/          # Git + delta
│           ├── qt6ct/        # Qt6 主题
│           ├── yazi/         # 终端文件管理器
│           ├── tmux/         # 终端复用器
│           ├── zellij/       # 终端复用器
│           └── wallpapers/   # 壁纸
└── scripts/                  # 安装脚本
```
