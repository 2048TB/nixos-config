# NixOS Desktop (Niri + Home Manager)

本配置基于 `nix-config-main` 的思路整理为可从 ISO 启动/安装的最小桌面方案，包含：

- Niri Wayland + Home Manager
- 开发工具链：Rust / Zig / Go / Node.js / Python
- 游戏支持：Steam / Proton / Wine
- 中文输入：Fcitx5 + Rime（小鹤音形，默认 schema: double_pinyin_flypy）
- impermanence/tmpfs 根分区 + 持久化（/persistent）
- 安全：AppArmor + nixpaks 沙箱 + Secure Boot（lanzaboote）
- 应用：Chrome / Telegram(nixpaks) / Noctalia Shell / Vicinae / Ghostty

## 重要路径约定

Home Manager 会从 `~/nixos-config` 读取配置文件：

```
/home/<user>/nixos-config/home/
```

如果你把仓库放在别的路径，需要在 `home/default.nix` 里修改 `repoRoot`。

## 需要手动调整的内容

1) **用户名**：默认 `nixos`，可通过环境变量 `NIXOS_USER` 配置（需要 `--impure`）。

2) **硬件配置**：
- 全自动脚本会用 `nixos-generate-config` 生成并覆盖
  `hosts/nixos-cconfig/hardware-configuration.nix`。
- 若手动安装，请替换 UUID 并确保单 NVMe：LUKS + Btrfs 子卷 + swapfile
  （@root/@nix/@persistent/@snapshots/@tmp/@swap）。
- `hosts/nixos-cconfig/impermanence.nix` 会强制将 `/` 设为 tmpfs，并配置 swapfile。

3) **GPU 选择**：
- 默认配置启用 `amdgpu+modesetting`，并提供 specialisation：
  - `gpu-amd`
  - `gpu-nvidia`
  - `gpu-none`
- 你可以在引导菜单中选择对应项（相当于“让我输入选择”）。
- 也可通过环境变量 `NIXOS_GPU`（需 `--impure`）覆盖默认驱动。
- 安装脚本会把检测结果写入 `hosts/nixos-cconfig/gpu-choice.txt` 作为默认值。

4) **Rime 小鹤**：
- 已自动注入 `default.custom.yaml`，默认启用 `double_pinyin_flypy`。
- 如需自定义词库/配置，可把文件放到 `home/fcitx5/rime/` 并提交到仓库。

5) **Noctalia 依赖**：
- 按官方文档启用 NetworkManager、Bluetooth、UPower、电源管理守护进程。citeturn0search0

6) **Vicinae**：
- 这里使用 nixpkgs 安装；若你想用官方脚本，可参考 Vicinae 文档。citeturn0search1

## ISO 构建

```bash
nix build .#nixos-cconfig-iso
```

生成的 ISO 在 `./result/iso/`。

## 全自动安装（ISO 环境）

从 Live ISO 进入后：

```bash
git clone <your-repo> ~/nixos-config
cd ~/nixos-config
sudo ./scripts/auto-install.sh
```

仅需输入：用户名与密码（LUKS 密码默认与用户密码相同，可用环境变量覆盖）。

可选环境变量：

- `NIXOS_USER`：用户名
- `NIXOS_PASSWORD`：用户密码
- `NIXOS_LUKS_PASSWORD`：LUKS 密码（默认等于用户密码）
- `NIXOS_DISK`：目标磁盘（如 `/dev/nvme0n1`，若系统只有一块 NVMe 会自动识别）
- `NIXOS_HOSTNAME`：主机名（默认 `nixos-cconfig`）
- `NIXOS_GPU`：GPU 选择（`nvidia`/`amd`/`none`，默认自动检测）
- `NIXOS_SWAP_SIZE_GB`：swapfile 大小（默认 32）

脚本会自动分区、加密、创建 Btrfs 子卷、生成配置并安装系统。
同时会自动检测 GPU（可用 `NIXOS_GPU` 覆盖）。

## 安装步骤简述（单 NVMe）

- 分区：ESP + LUKS
- 在 LUKS 之上创建 Btrfs + 子卷
- 在 `@swap` 创建 swapfile
- `nixos-generate-config --root /mnt` 后替换模板里的 UUID
- `nixos-rebuild switch --flake .#nixos-cconfig`

## Secure Boot（lanzaboote）

- 默认关闭（避免影响 ISO 构建）。
- 需要初始化 `/etc/secureboot`；可用 `sbctl` 生成/注册密钥。
- 启用方式：在 `hosts/nixos-cconfig/default.nix` 将 `boot.lanzaboote.enable` 改为 `true`，
  并确保系统已安装到磁盘。
