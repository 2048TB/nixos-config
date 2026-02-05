# NixOS Desktop (Niri + Home Manager)

一键安装的 NixOS 桌面配置，基于 Niri Wayland + Home Manager。

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
sudo ./scripts/auto-install.sh
```

无需预先克隆（脚本会自动下载仓库）：

```bash
curl -sSL https://raw.githubusercontent.com/2048TB/nixos-config/main/scripts/auto-install.sh | sudo bash
```

无交互安装（通过环境变量）：

```bash
export NIXOS_USER="myname"
export NIXOS_PASSWORD="mypassword"
export NIXOS_LUKS_PASSWORD="lukspassword"
export NIXOS_DISK="/dev/nvme0n1"
export NIXOS_HOSTNAME="my-nixos"
export NIXOS_GPU="nvidia"  # none/amd/nvidia/amd-nvidia-hybrid
export NIXOS_SWAP_SIZE_GB="64"

sudo -E ./scripts/auto-install.sh
```

安装完成后：

```bash
cd ~/nixos-config
sudo nixos-rebuild switch --flake .#<hostname>
```

---

## 安装流程概览

脚本会执行：
- 分区与 LUKS 加密
- Btrfs 子卷创建与挂载
- swapfile 创建
- 生成硬件配置
- 拷贝仓库到 `/home/<user>/nixos-config`
- 写入密码哈希到 `/persistent/etc/*` 并同步到 `/etc/*`
- `nixos-install --impure --flake .#<hostname>`

安全保护：
- 非空磁盘默认拒绝格式化（需 `FORCE=1` 或 `NIXOS_AUTO_ERASE=1`）
- 失败自动卸载挂载点并关闭 LUKS

---

## 环境变量

| 变量 | 默认值 | 说明 |
|---|---|---|
| `NIXOS_USER` | 交互输入 | 用户名（必须符合 Linux 规范） |
| `NIXOS_PASSWORD` | 交互输入 | 用户密码 |
| `NIXOS_LUKS_PASSWORD` | 同用户密码 | LUKS 解密密码 |
| `NIXOS_DISK` | 自动检测 | 目标磁盘（如 `/dev/sda`） |
| `NIXOS_HOSTNAME` | `nixos-config` | 主机名 |
| `NIXOS_GPU` | 交互选择 | `none` / `amd` / `nvidia` / `amd-nvidia-hybrid` |
| `NIXOS_SWAP_SIZE_GB` | `32` | swapfile 大小（GB，正整数） |
| `NIXOS_LUKS_ITER_TIME` | `5000` | LUKS 密钥派生时间（ms） |
| `NIXOS_CONFIG_PATH` | `~/nixos-config` | 配置仓库路径（Home Manager 读取） |
| `NIXOS_AUTO_ERASE` | `1` | 自动擦除非空磁盘（设为 `0` 可强制确认） |
| `FORCE` | `0` | 允许格式化已有分区（`1` 启用） |

---

## GPU 选择与覆盖

安装时脚本会提示选择 GPU 模式，或读取 `NIXOS_GPU`。

运行时覆盖（需要 `--impure`）：

```bash
NIXOS_GPU=amd sudo nixos-rebuild switch --impure --flake .#<hostname>
```

GPU 启动菜单切换（可选）：

```bash
export ENABLE_GPU_SPECIALISATION=1
```

该选项默认关闭，开启后会生成额外的启动条目。

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

以下文件由 `scripts/auto-install.sh` 生成，请勿手动编辑：
- `nix/hosts/nixos-config-hardware.nix`
- `nix/vars/detected-gpu.txt`

---

## 目录结构

```
.
├── flake.nix
├── outputs.nix
├── nix/
│   ├── hosts/
│   ├── modules/
│   ├── hardening/
│   ├── vars/
│   └── home/
└── scripts/
```

---

## 可选：构建 ISO

```bash
nix build .#nixos-config-iso
```
