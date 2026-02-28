# Nix 常用命令速查

面向日常使用的精简清单。
优先使用 `just`（仓库内已封装常用流程），必要时再直接调用 `nix*` 命令。

---

## 统一入口（推荐）

```bash
just hosts
just install-live-check host=zly
just install-live host=zly disk=/dev/nvme0n1
just switch host=zly

just switch host=zky

just darwin-check darwin_host=zly-mac
just darwin-switch darwin_host=zly-mac
```

---

## Flake Apps（对齐参考管理方式）

```bash
# Linux: 构建检查 / 切换 / 安装 / 清理
nix run .#build
nix run .#build-switch
nix run .#install
nix run .#clean

# Darwin: 构建检查 / 切换
nix run .#build
nix run .#build-switch
```

可选环境变量：

```bash
NIXOS_HOST=zky nix run .#build-switch
NIXOS_DISK_DEVICE=/dev/nvme0n1 nix run .#install
DARWIN_HOST=zly-mac nix run .#build-switch
NIXOS_CONFIG_REPO=/persistent/nixos-config nix run .#build
```

---

## Live ISO 安装（NixOS）

```bash
just install-live-check host=zly
just install-live host=zly disk=/dev/nvme0n1

# 另一台 x86
just install-live-check host=zky
just install-live host=zky disk=/dev/nvme0n1
```

如不使用 `just`，可执行等价命令：

```bash
sudo env NIXOS_DISK_DEVICE=/dev/nvme0n1 \
  nix --extra-experimental-features "nix-command flakes" \
  run github:nix-community/disko -- --mode disko --flake .#zly

findmnt /mnt/persistent
sudo rm -rf /mnt/persistent/nixos-config
sudo mkdir -p /mnt/persistent/nixos-config
sudo cp -a ./. /mnt/persistent/nixos-config/

sudo env NIXOS_DISK_DEVICE=/dev/nvme0n1 \
  nixos-install --impure --flake /mnt/persistent/nixos-config#zly
```

---

## 系统重建

```bash
sudo nixos-rebuild switch --flake /etc/nixos#zly
sudo nixos-rebuild boot --flake /etc/nixos#zly
sudo nixos-rebuild test --flake /etc/nixos#zly
sudo nixos-rebuild dry-build --flake /etc/nixos#zly
sudo nixos-rebuild switch --flake /etc/nixos#zly |& nom
```

通过 `justfile` 可切换目标 NixOS 主机（默认 `host := "zly"`）：

```bash
just switch host=zky
just check host=zky
```

说明：GPU 使用 `hosts/vars/default.nix` 中的 `gpuMode` 固定配置。

---

## Darwin（macOS）

```bash
just hosts
just nixos-hosts
just darwin-hosts
just darwin-check
just darwin-switch
```

说明：默认使用 `justfile` 里的 `darwin_host := "zly-mac"`，可临时覆盖：

```bash
just darwin-switch darwin_host=<host>
```

说明：Darwin 侧已启用 `nix-homebrew`，`darwin-switch` 会声明式确保 Homebrew 可用，并按配置安装 casks（如 `ghostty`）。

---

## Flake 维护

```bash
nix flake update --flake path:/persistent/nixos-config
nix flake lock --update-input nixpkgs --flake path:/persistent/nixos-config
nix flake show path:/persistent/nixos-config
nix flake check path:/persistent/nixos-config
nix flake metadata path:/persistent/nixos-config
```

---

## 配置验证（推荐顺序）

```bash
just fmt
just lint
just dead
just flake-check
just check

# 可选：完整系统构建验证（不切换）
nix build path:/persistent/nixos-config#nixosConfigurations.zly.config.system.build.toplevel --no-link
```

说明：`just check` 依赖 `sudo nixos-rebuild dry-build`。在无交互密码环境下，可先用上面的 `nix build --no-link` 作为等价构建校验。

---

## 垃圾回收与优化

```bash
sudo nix-collect-garbage --delete-older-than 7d
sudo nix-collect-garbage -d
sudo nix-store --optimise
```

---

## 构建与查看

```bash
nix build .#<output>
ls -la result/

nix log /nix/store/<path>
```

查看差异：

```bash
nix store diff-closures /nix/var/nix/profiles/system-{旧,新}-link
```

---

## 包查询

```bash
nix search nixpkgs <name>
nix shell nixpkgs#<pkg>
nix run nixpkgs#<pkg>
```

查看依赖树：

```bash
nix-tree /run/current-system
```

---

## Home Manager

本项目 Home Manager 作为 NixOS module 集成，不支持独立运行。配置更改通过 `nixos-rebuild` 统一应用：

```bash
sudo nixos-rebuild switch --flake /etc/nixos#zly
```

查看 HM 世代历史（无需 `home-manager` CLI）：

```bash
nix-env --list-generations --profile /nix/var/nix/profiles/per-user/$USER/home-manager
```

---

## 主题相关排查

```bash
# 查看 GTK 暗色偏好
gsettings get org.gnome.desktop.interface color-scheme

# 重启 Nautilus（让主题配置立即刷新）
nautilus -q
```

---

## 密码哈希更新

```bash
mkpasswd -m sha-512
mkpasswd -m sha-512
```

将两次输出分别写入 `hosts/vars/default.nix` 的 `userPasswordHash` 与 `rootPasswordHash`，然后执行：

```bash
sudo nixos-rebuild switch --flake /etc/nixos#zly
```

---

## 常用排查

```bash
journalctl -u <service> --no-pager
journalctl --user -u <service> --no-pager

# 桌面会话常用日志
journalctl --user -b -u waybar.service -u xdg-desktop-portal.service --no-pager
journalctl --user -b --no-pager | rg -i 'niri|waybar|portal|pipewire|wireplumber|swaync'

nixos-version
readlink /run/current-system
```

---

## GitHub 同步

```bash
git status
git add -A
git commit -m "docs: refresh repository documentation"
git push origin HEAD
```
