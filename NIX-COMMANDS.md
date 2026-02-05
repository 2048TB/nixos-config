# Nix 常用命令速查

面向日常使用的精简清单。

---

## 系统重建

```bash
sudo nixos-rebuild switch --flake .#nixos-config
sudo nixos-rebuild boot --flake .#nixos-config
sudo nixos-rebuild test --flake .#nixos-config
sudo nixos-rebuild dry-build --flake .#nixos-config
sudo nixos-rebuild switch --flake .#nixos-config |& nom
```

使用环境变量覆盖（需 `--impure`）：

```bash
NIXOS_GPU=amd sudo nixos-rebuild switch --impure --flake .#nixos-config
```

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

nix build .#nixos-config-iso
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

```bash
home-manager switch --flake .#<user>
home-manager generations
home-manager switch --rollback
home-manager expire-generations "-7 days"
```

---

## 常用排查

```bash
journalctl -u <service>
journalctl --user -u <service>

nixos-version
readlink /run/current-system
```
