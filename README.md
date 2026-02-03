# NixOS Desktop (Niri + Home Manager)

一键安装、全自动硬件适配的 NixOS 桌面配置，包含：

📖 **[快捷键说明](./KEYBINDINGS.md)** - 窗口管理器和终端快捷键
📖 **[Nix 命令速查](./NIX-COMMANDS.md)** - NixOS 和 Flake 常用命令
⚡ **[Justfile 命令](./justfile)** - 使用 `just` 简化日常操作

- **桌面环境**: Niri Wayland + Home Manager + Noctalia Shell
- **开发工具链**: Rust / Zig / Go / Node.js / Python
- **游戏支持**: Steam / Proton-GE / Wine / Lutris
- **中文输入**: Fcitx5 中文拼音
- **终端工具**: Ghostty + Tmux + Zellij + 现代化 CLI 工具链 (bat/fd/eza/ripgrep/duf/jq)
- **存储方案**: tmpfs 根分区 + Btrfs + LUKS 全盘加密 + preservation 持久化
- **安全加固**: AppArmor + Secure Boot 支持
- **应用软件**: Chrome / Telegram / VSCode / MPV
- **性能优化**: 完全使用 Binary Cache，0 本地编译，15 分钟快速安装

---

## ⚡ 性能特性

本配置经过深度优化，确保最快的安装速度：

- ✅ **0 本地编译** - 所有包使用官方 Binary Cache
- ✅ **96%+ 缓存命中率** - 配置 Nix Community + Wayland Cachix
- ✅ **15-20 分钟快速安装** - 仅网络下载，无编译等待
- ✅ **1.2GB 精简 ISO** - 移除冗余依赖，优化体积 52%

### Binary Cache 配置

已自动配置以下缓存源：
- `cache.nixos.org` - 官方缓存（核心系统）
- `nix-community.cachix.org` - 社区包（Niri, 游戏工具, 开发工具）
- `nixpkgs-wayland.cachix.org` - Wayland 生态（Noctalia Shell 等）
- `cache.garnix.io` - 额外社区缓存（Rust 工具链、游戏工具）

### 包体积统计

| 类别 | 下载体积 | 说明 |
|------|---------|------|
| 核心系统 | ~1.5 GB | 内核、systemd、基础工具 |
| 桌面环境 | ~800 MB | Niri, Wayland, 字体 |
| 开发工具 | ~2.5 GB | Rust/Go/Node/Python/Zig 全工具链 |
| 游戏工具 | ~4 GB | Steam/Wine/Proton/Lutris |
| 其他应用 | ~1 GB | Chrome/VSCode/Telegram 等 |
| **总计** | **~9.8 GB** | 解压后约 15.6 GB |

---

## ⚡ 快速开始（使用 Just）

安装完成后，使用 `just` 命令简化日常操作：

```bash
# 查看所有可用命令
just

# 常用命令
just switch          # 应用配置
just quick           # 检查 + 应用
just clean           # 清理旧世代
just upgrade         # 更新并应用
just push "消息"      # 提交并推送到 GitHub

# 查看文档
just keys            # 快捷键说明
just commands        # Nix 命令
just help            # 常用命令参考
```

完整命令列表查看 [justfile](./justfile)。

---

## 🚀 一键安装

从 Live ISO 启动后，复制粘贴以下命令：

```bash
git clone https://github.com/2048TB/nixos-config ~/nixos-config && cd ~/nixos-config && sudo ./scripts/auto-install.sh
```

### 其他安装方式

### 方式 2: Curl 下载（备选）

如果没有 git，可用 curl 下载：

```bash
# 下载并解压
curl -sSL https://github.com/2048TB/nixos-config/archive/main.tar.gz | tar xz
cd nixos-config-main

# 运行安装脚本
sudo ./scripts/auto-install.sh
```

### 方式 3: 使用环境变量（无交互安装）

```bash
# 设置所有参数
export NIXOS_USER="myname"
export NIXOS_PASSWORD="mypassword"
export NIXOS_LUKS_PASSWORD="lukspassword"
export NIXOS_DISK="/dev/nvme0n1"
export NIXOS_HOSTNAME="my-nixos"
export NIXOS_GPU="nvidia"  # 或 amd/none
export NIXOS_SWAP_SIZE_GB="64"

# 克隆配置
git clone https://github.com/2048TB/nixos-config ~/nixos-config
cd ~/nixos-config

# 自动安装（无交互）
sudo -E ./scripts/auto-install.sh
```

### 构建自定义 ISO（可选）

在开发机上构建包含配置的 ISO：

```bash
nix build .#nixos-config-iso
dd if=result/iso/nixos-*.iso of=/dev/sdX bs=4M status=progress
```

---

## ⚙️ 安装流程说明

### 自动检测与配置

安装脚本会自动：
- ✅ 检测磁盘（支持 NVMe / SATA / 虚拟机）
- ✅ 检测 GPU（NVIDIA / AMD / 通用驱动）
- ✅ 检测网络连接
- ✅ 验证用户名格式
- ✅ 生成硬件配置 (`hardware-configuration.nix`)
- ✅ 更新用户变量 (`nix/vars/default.nix`)

### 安全保护机制

脚本包含多重安全检查：

1. **磁盘保护**: 默认拒绝格式化已有分区的磁盘
   ```bash
   # 强制安装需要显式设置
   export FORCE=1
   sudo -E ./scripts/auto-install.sh
   ```

2. **失败自动清理**: 安装失败时自动卸载挂载点和 LUKS 容器

3. **用户名验证**: 只允许符合 Linux 规范的用户名

4. **网络检查**: 安装前验证 GitHub 可访问性

### 磁盘布局

```
/dev/nvme0n1
├── nvme0n1p1  EFI (512MB, FAT32)
└── nvme0n1p2  LUKS 加密容器
    └── crypted-nixos (Btrfs)
        ├── @root       → tmpfs (重启清空)
        ├── @nix        → /nix
        ├── @persistent → /persistent
        ├── @snapshots  → /snapshots
        ├── @tmp        → /tmp
        └── @swap       → /swap (含 swapfile)
```

---

## 📝 环境变量完整列表

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `NIXOS_USER` | (交互输入) | 用户名（系统用户 + Home Manager，必须符合 Linux 规范） |
| `NIXOS_PASSWORD` | (交互输入) | 用户密码 |
| `NIXOS_LUKS_PASSWORD` | 同用户密码 | LUKS 解密密码 |
| `NIXOS_DISK` | 自动检测 | 目标磁盘（如 `/dev/sda`） |
| `NIXOS_HOSTNAME` | `nixos-config` | 主机名 |
| `NIXOS_GPU` | 自动检测 | GPU 驱动 (`nvidia`/`amd`/`none`) |
| `NIXOS_SWAP_SIZE_GB` | `32` | swapfile 大小（GB） |
| `NIXOS_LUKS_ITER_TIME` | `5000` | LUKS 密钥派生时间（ms） |
| `NIXOS_CONFIG_PATH` | `~/nixos-config` | 配置仓库路径（优先级：NIXOS_CONFIG_PATH > `~/nixos-config` > `nix/vars/default.nix`） |
| `FORCE` | `0` | 强制格式化已有分区（`1` 启用） |

---

## 🛠️ GPU 驱动配置

### 自动检测规则

1. 检测 `/sys/bus/pci/devices/*/vendor`
   - `0x10de` → NVIDIA
   - `0x1002` → AMD

2. fallback 到 `lspci` 解析

3. 检测失败 → 使用通用 `modesetting` 驱动

### 运行时切换

系统启动时可在 GRUB/systemd-boot 菜单选择：
- `NixOS (gpu-nvidia)` - NVIDIA 专有驱动
- `NixOS (gpu-amd)` - AMD 开源驱动
- `NixOS (gpu-none)` - 通用 modesetting

### 手动覆盖

```bash
# 方式 1: 修改检测结果文件
echo "nvidia" > nix/vars/detected-gpu.txt
sudo nixos-rebuild switch --flake .#nixos-config

# 方式 2: 环境变量（需 --impure）
NIXOS_GPU=amd sudo nixos-rebuild switch --impure --flake .#nixos-config
```

---

## 📂 配置路径约定

Home Manager 读取配置的优先级如下：

1. `NIXOS_CONFIG_PATH`（如果设置）
2. `~/nixos-config`（存在则用）
3. `nix/vars/default.nix` 中的 `configRoot`

若仓库位置不同，通过环境变量指定：

```bash
export NIXOS_CONFIG_PATH=/path/to/your/repo
```

或修改 `nix/vars/default.nix` 中的 `configRoot`（安装脚本会自动更新）。

---

## 🔧 手动安装步骤

如果不使用自动脚本，参考以下流程：

1. **分区和加密**:
   ```bash
   parted /dev/sda mklabel gpt
   parted /dev/sda mkpart ESP fat32 2MiB 514MiB
   parted /dev/sda set 1 esp on
   parted /dev/sda mkpart primary 514MiB 100%

   mkfs.fat -F 32 -n ESP /dev/sda1
   cryptsetup luksFormat /dev/sda2
   cryptsetup luksOpen /dev/sda2 crypted-nixos
   ```

2. **创建 Btrfs 子卷**:
   ```bash
   mkfs.btrfs /dev/mapper/crypted-nixos
   mount /dev/mapper/crypted-nixos /mnt
   btrfs subvolume create /mnt/@root
   btrfs subvolume create /mnt/@nix
   btrfs subvolume create /mnt/@persistent
   btrfs subvolume create /mnt/@snapshots
   btrfs subvolume create /mnt/@tmp
   btrfs subvolume create /mnt/@swap
   umount /mnt
   ```

3. **挂载子卷**:
   ```bash
   mount -o subvol=@root,compress-force=zstd:1,noatime /dev/mapper/crypted-nixos /mnt
   mkdir -p /mnt/{nix,persistent,snapshots,tmp,swap,boot}
   mount -o subvol=@nix,compress-force=zstd:1,noatime /dev/mapper/crypted-nixos /mnt/nix
   mount -o subvol=@persistent,compress-force=zstd:1 /dev/mapper/crypted-nixos /mnt/persistent
   mount -o subvol=@snapshots,compress-force=zstd:1,noatime /dev/mapper/crypted-nixos /mnt/snapshots
   mount -o subvol=@tmp,compress-force=zstd:1 /dev/mapper/crypted-nixos /mnt/tmp
   mount -o subvol=@swap /dev/mapper/crypted-nixos /mnt/swap
   mount /dev/sda1 /mnt/boot
   ```

4. **创建 swapfile**:
   ```bash
   btrfs filesystem mkswapfile --size 32g --uuid clear /mnt/swap/swapfile
   ```

5. **生成并修改配置**:
   ```bash
   nixos-generate-config --root /mnt
   # 复制 /mnt/etc/nixos/hardware-configuration.nix 到 nix/hosts/nixos-config-hardware.nix
   ```

6. **安装系统**:
   ```bash
   cd ~/nixos-config
   NIXOS_GPU=nvidia nixos-install --impure --flake .#nixos-config
   ```

---

## 🔒 Secure Boot（lanzaboote）

默认关闭，启用步骤：

1. 安装系统后，生成密钥：
   ```bash
   sbctl create-keys
   sbctl enroll-keys -m
   ```

2. 创建标记文件：
   ```bash
   sudo mkdir -p /etc/secureboot
   ```

3. 修改 `nix/modules/system.nix`（或在 host 配置中覆盖）：
   ```nix
   boot.lanzaboote.enable = true;
   ```

4. 重新构建系统：
   ```bash
   sudo nixos-rebuild switch --flake .#nixos-config
   ```

---

## 🐛 故障排查

### 安装失败：磁盘已有分区

```
ERROR: Disk /dev/sda appears to have existing partitions
```

**解决方案**:
```bash
export FORCE=1
sudo -E ./scripts/auto-install.sh
```

### GPU 检测错误

手动指定 GPU 类型：
```bash
export NIXOS_GPU=amd
sudo -E ./scripts/auto-install.sh
```

### 配置路径错误

Home Manager 找不到配置文件：
```bash
# 检查实际路径
ls -la ~/nixos-config/nix/home/

# 设置正确路径
export NIXOS_CONFIG_PATH="$HOME/nixos-config"
sudo nixos-rebuild switch --flake .#nixos-config
```

### 首次启动权限问题

系统会在第一次启动时自动修复 `/persistent/home` 的权限。如果仍有问题：
```bash
sudo chown -R $USER:$USER /persistent/home/$USER
```

---

## 📦 ISO 构建

```bash
nix build .#nixos-config-iso
```

生成的 ISO 位于 `./result/iso/nixos-*.iso`。

---

## 🧪 开发环境

```bash
nix develop

# 可用命令：
nix flake check        # 检查配置
nixpkgs-fmt .          # 格式化代码
statix check .         # 静态分析
deadnix .              # 检测死代码
```

---

## 📚 目录结构

```
.
├── flake.nix                    # Flake 入口
├── outputs.nix                  # 输出定义
├── nix/                         # NixOS 相关配置
│   ├── hosts/                   # 主机配置
│   │   ├── nixos-config.nix
│   │   ├── nixos-config-hardware.nix  # 安装时生成
│   │   └── nixos-config-gpu-choice.txt # 旧式 GPU 选择（可选）
│   ├── modules/                 # 功能模块
│   │   ├── system.nix           # 系统基础（含桌面/服务/存储）
│   │   ├── hardware.nix         # 硬件支持
│   ├── hardening/               # 安全加固
│   │   ├── apparmor.nix
│   │   └── nixpaks/
│   ├── vars/                    # 全局变量
│   │   ├── default.nix
│   │   └── detected-gpu.txt     # GPU 检测结果
│   ├── lib/                     # 自定义函数
│   └── home/                    # Home Manager 配置
│       ├── default.nix
│       └── configs/             # 配置素材集中目录
│           ├── niri/
│           ├── niriswitcher/
│           ├── noctalia/
│           ├── fcitx5/
│           ├── ghostty/
│           ├── shell/
│           └── wallpapers/
├── scripts/                     # 工具脚本
│   └── auto-install.sh          # 一键安装脚本
```

---

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

---

## 📄 许可证

MIT License
