# Nix 命令速查

只保留最小脚本 surface 仍需要的命令。通用说明见 `docs/README.md`。

---

## 1. 安装

```bash
just host=zly disk=/dev/nvme0n1 install
```

直接调用脚本：

```bash
REPO=/persistent/nixos-config
bash "$REPO/nix/scripts/admin/install-live.sh" --host zly --disk /dev/nvme0n1 --repo "$REPO"
```

---

## 2. Flake 与锁文件

```bash
just update
just update-nixpkgs
just info
```

手动执行 read-only flake eval/build/show 时，优先先取 filtered repo：

```bash
REPO=/persistent/nixos-config
flake_repo="$(bash "$REPO/nix/scripts/admin/print-flake-repo.sh" "$REPO")"
nix flake show "path:$flake_repo"
nix eval "path:$flake_repo#nixosConfigurations" --apply builtins.attrNames
```

查看导出面：

```bash
REPO=/persistent/nixos-config
flake_repo="$(bash "$REPO/nix/scripts/admin/print-flake-repo.sh" "$REPO")"
nix eval "path:$flake_repo#packages.x86_64-linux" --apply builtins.attrNames
nix eval "path:$flake_repo#overlays" --apply builtins.attrNames
nix eval "path:$flake_repo#nixosModules" --apply builtins.attrNames
```

---

## 3. 密钥管理（sops）

```bash
just sops-init-create
just sops-init
just sops-recovery-init
just password-hashes
just password-set-hash '<sha512-hash>'
just ssh-key-set
just sops-recipients
just sops-host-key-add <host> <pub>
just sops-rekey
```

---

## 4. Git 安全

```bash
just hooks-enable
just guard-secrets
just status
```
