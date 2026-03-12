# Nix 命令速查

只列命令，不重复背景、FAQ 与环境差异。通用说明见 `docs/README.md`，环境差异见 `docs/ENV-USAGE.md`。

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

注：显式传入的 `--repo` 必须是有效 flake repo。

---

## 2. Flake 与锁文件

```bash
just update
just update-nixpkgs
just info
just show
just metadata
just hosts
```

read-only flake eval/build/show：

```bash
REPO=/persistent/nixos-config
flake_repo="$(bash "$REPO/nix/scripts/admin/print-flake-repo.sh" "$REPO")"
nix flake show "path:$flake_repo"
nix eval "path:$flake_repo#nixosConfigurations" --apply builtins.attrNames
```

导出面速查：

```bash
REPO=/persistent/nixos-config
flake_repo="$(bash "$REPO/nix/scripts/admin/print-flake-repo.sh" "$REPO")"
nix eval "path:$flake_repo#packages.x86_64-linux" --apply builtins.attrNames
nix eval "path:$flake_repo#overlays" --apply builtins.attrNames
nix eval "path:$flake_repo#nixosModules" --apply builtins.attrNames
```

---

## 3. build / switch / clean

```bash
just host=zly build
just host=zly dry-build
just host=zly switch
just host=zly boot
just host=zly test
just gc
just optimize
just clean
just use
```

---

## 4. 密钥管理（sops）

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

## 5. Git 安全

```bash
just hooks-enable
just guard-secrets
just status
```

也可从仓库外直接调用：

```bash
bash /persistent/nixos-config/nix/scripts/admin/sops.sh recipients
bash /persistent/nixos-config/nix/scripts/admin/guard-secrets.sh
```
