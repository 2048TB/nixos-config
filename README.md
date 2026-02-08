# NixOS Desktop (Niri + Home Manager)

可复现的 NixOS 桌面配置，基于 Niri Wayland + Home Manager。

相关文档：
- `KEYBINDINGS.md` 快捷键说明
- `NIX-COMMANDS.md` 常用 Nix 命令速查
- `justfile` 日常操作命令
- `CLAUDE.md` 项目维护约定（给 AI/自动化工具）

主要特性：
- Wayland 桌面：Niri + Noctalia Shell
- 开发工具链：Rust / Zig / Go / Node.js / Python
- 游戏支持：Steam / Proton / Wine / Lutris
- 中文输入：Fcitx5
- 存储：tmpfs 根分区 + Btrfs + LUKS + preservation 持久化
- 安全：AppArmor（可选 Secure Boot）

---

## 快速开始

推荐方式（在 Live ISO 中）：

```bash
git clone https://github.com/2048TB/nixos-config ~/nixos-config
cd ~/nixos-config
```

1. 设置密码哈希（必须）

```bash
mkpasswd -m sha-512
```

把输出填入 `flake.nix` 的 `myvars.userPasswordHash` 和 `myvars.rootPasswordHash`。

2. 磁盘分区与挂载（会清空目标磁盘）

```bash
sudo nix --extra-experimental-features nix-command --extra-experimental-features flakes \
  run github:nix-community/disko -- \
  --mode disko --flake .#zly

findmnt /mnt/boot
```

3. 安装系统

```bash
sudo nixos-install --flake .#zly
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
5. 如果你将来修改 disko 布局（改名/移除 `/persistent` 子卷），必须同步调整 disko 配置里 `/persistent` 的挂载点。
6. 如果你将来修改 disko 布局（改名/移除 `/persistent` 子卷），必须同步调整 `fileSystems."/persistent"`。
7. 如果你将来修改 disko 布局（改名/移除 `/persistent` 子卷），必须同步调整 `tmpfiles` 规则（`/etc/nixos` 的 symlink）。

---

## 安装脚本（Live ISO）

已提供脚本：`scripts/install-live.sh`

```bash
cd ~/nixos-config
./scripts/install-live.sh
```

默认等价于：
- 自动探测并选择最大非 USB 磁盘
- 固定流程：`disko -> EFI 挂载检查 -> 交互式修改 LUKS 密码 -> nixos-install`（高危，会重建分区）
- 无需命令参数

---

## 一键式完整安装命令（Live ISO）

```bash
git clone https://github.com/2048TB/nixos-config ~/nixos-config
cd ~/nixos-config

sudo nix --extra-experimental-features "nix-command flakes" \
  run github:nix-community/disko -- --mode disko --flake .#zly

findmnt /mnt/boot

sudo nixos-install --flake .#zly
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

## 生成文件

---

## 目录结构

```
.
├── flake.nix
├── nix/
│   ├── hosts/
│   ├── modules/
│   └── home/
└── scripts/
```

---

## 可选：构建 ISO

（当前未提供 ISO 输出）

