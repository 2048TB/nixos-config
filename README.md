# NixOS Desktop (niri + Home Manager)

可复现的 NixOS 桌面配置，基于 niri Wayland + Home Manager。

相关文档：
- `KEYBINDINGS.md` 快捷键说明（niri + DMS / Ghostty / Tmux / Zellij / Foot）
- `NIX-COMMANDS.md` 常用 Nix 命令速查
- `AGENTS.md` 贡献与协作约定
- `justfile` 日常操作命令
- `CLAUDE.md` 项目维护约定（给 AI/自动化工具）

主要特性：
- Wayland 桌面：niri + DankMaterialShell (DMS)
- 终端：Ghostty（主力）+ Foot + Tmux + Zellij
- 开发工具链：Rust / Zig / Go / Node.js / Python
- 游戏支持：Steam / Proton / Wine / Lutris
- 中文输入：Fcitx5
- 存储：tmpfs 根分区 + Btrfs + LUKS + 持久化
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
1. `/etc/nixos` 只是入口，兼容传统用法与工具习惯。
2. 真实仓库在 `/persistent/nixos-config`（持久化盘），避免 `/` 为 tmpfs 时丢失配置。
3. 编辑 `/etc/nixos` 等同于编辑 `/persistent/nixos-config`。
4. symlink 的创建依赖 `/persistent` 在早期启动阶段已挂载（`fileSystems."/persistent".neededForBoot = true`）。
5. 修改 disko 布局时，需同步调整挂载点、`fileSystems."/persistent"` 及 `tmpfiles` 规则。

---

## 安装脚本（Live ISO）

已提供脚本：`scripts/install-live.sh`

```bash
cd ~/nixos
./scripts/install-live.sh
```

默认行为：
- 自动探测并选择最大非 USB 磁盘
- 固定流程：预清理 → disko → EFI 检查 → LUKS 密码 → nixos-install → 同步 flake → dry-build 校验
- 可选环境变量：`NIXOS_DISK_DEVICE=/dev/<disk>`、`DRY_RUN=1`、`CONFIRM=0`

---

## 配置入口

主要变量集中在 `flake.nix` 的 `myvars`：
- `username` / `hostname`
- `gpuMode`（如 `amd-nvidia-hybrid`）
- `swapSizeGb`
- `userPasswordHash` / `rootPasswordHash`

---

## 主题

全局暗色 + 分层覆盖：
- GTK：`dconf.settings` → `prefer-dark` + `Adwaita-dark`
- Qt6：`qt6ct` → `darker.conf`
- Wayland 组件：Catppuccin Mocha 风格
- 浏览器/Electron 应用需在应用内单独设置

---

## Shell 快捷命令

`zsh` 内置快捷函数（见 `nix/home/configs/shell/zshrc`）：
- `ccv` / `ccv r`：Claude Code 启动/恢复
- `cdx` / `cdx r`：Codex 启动/恢复

---

## 磁盘布局

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
│           ├── ghostty/      # Ghostty 终端
│           ├── foot/         # Foot 终端
│           ├── tmux/         # Tmux 终端复用器
│           ├── zellij/       # Zellij 终端复用器
│           ├── waybar/       # 状态栏
│           ├── wlogout/      # 电源菜单
│           ├── fuzzel/       # 应用启动器
│           ├── shell/        # zsh/vim
│           ├── fcitx5/       # 输入法
│           ├── git/          # Git + delta
│           ├── qt6ct/        # Qt6 主题
│           ├── yazi/         # 终端文件管理器
│           └── wallpapers/   # 壁纸
└── scripts/                  # 安装脚本
```
