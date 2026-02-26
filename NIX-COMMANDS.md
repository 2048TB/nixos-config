# Nix 常用命令速查

面向日常使用的精简清单。
优先使用 `just`（仓库内已封装常用流程），必要时再直接调用 `nix*` 命令。

---

## 系统重建

```bash
sudo nixos-rebuild switch --flake /etc/nixos#zly
sudo nixos-rebuild boot --flake /etc/nixos#zly
sudo nixos-rebuild test --flake /etc/nixos#zly
sudo nixos-rebuild dry-build --flake /etc/nixos#zly
sudo nixos-rebuild switch --flake /etc/nixos#zly |& nom
```

说明：GPU 使用 `flake.nix` 中的 `myvars.gpuMode` 固定配置。

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

将两次输出分别写入 `flake.nix` 的 `myvars.userPasswordHash` 与 `myvars.rootPasswordHash`，然后执行：

```bash
sudo nixos-rebuild switch --flake /etc/nixos#zly
```

---

## 常用排查

```bash
journalctl -u <service> --no-pager
journalctl --user -u <service> --no-pager

# 桌面会话常用日志
journalctl --user -b -u waybar.service -u hypridle.service -u xdg-desktop-portal.service --no-pager
journalctl --user -b --no-pager | rg -i 'hyprland|waybar|portal|pipewire|wireplumber|swaync'

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
