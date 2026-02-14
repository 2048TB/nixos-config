# Nix 常用命令速查

面向日常使用的精简清单。

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
nix flake update
nix flake lock --update-input nixpkgs
nix flake show
nix flake check
nix flake metadata
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

查看 HM 世代历史：

```bash
home-manager generations
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
journalctl -u <service>
journalctl --user -u <service>

nixos-version
readlink /run/current-system
```
