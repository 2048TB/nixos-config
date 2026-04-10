# Nix 命令速查

只列命令，不写背景。行为说明与风险边界见 `docs/README.md`，环境差异见 `docs/ENV-USAGE.md`。

## 1. 安装

```bash
just host=zly disk=/dev/nvme0n1 install
bash /persistent/nixos-config/nix/scripts/admin/install-live.sh --host zly --disk /dev/nvme0n1 --repo /persistent/nixos-config
```

## 2. Flake / Lock / 只读检查

```bash
just update
just update-nixpkgs
just info
just show
just metadata
just hosts
just flake-check
just flake-check-exec
just registry-schema-check
just registry-meta-sync-check
just validate-local
just validate-local-full
```

```bash
REPO=/persistent/nixos-config
flake_repo="$(bash "$REPO/nix/scripts/admin/print-flake-repo.sh" "$REPO")"
nix flake show "path:$flake_repo"
nix flake check --all-systems --no-build "path:$flake_repo"
nix build "path:$flake_repo#checks.x86_64-linux.pre-commit-check"
nix shell nixpkgs#check-jsonschema -c check-jsonschema --schemafile "$REPO/nix/hosts/registry/systems.schema.json" "$REPO/nix/hosts/registry/systems.toml"
bash "$REPO/nix/scripts/admin/host-meta-schema-sync.sh"
nix eval "path:$flake_repo#nixosConfigurations" --apply builtins.attrNames
nix eval "path:$flake_repo#packages.x86_64-linux" --apply builtins.attrNames
nix eval "path:$flake_repo#overlays" --apply builtins.attrNames
nix eval "path:$flake_repo#nixosModules" --apply builtins.attrNames
```

## 3. 系统级命令

```bash
just host=zly build
just host=zly dry-build
just host=zly check
just host=zly switch
just host=zly boot
just host=zly test
just host=zly upgrade
```

## 4. 清理

```bash
just gc
just clean
just clean-all
just optimize
just use
```

## 5. `sops`

```bash
just sops-init
just sops-init-create
just sops-init-rotate
just sops-recovery-init
just sops-recipients
just sops-host-key-add zly /etc/ssh/ssh_host_ed25519_key.pub
just sops-rekey
just password-hash
just password-hashes
just password-set-hash '<sha512-hash>'
just ssh-key-set
```

```bash
bash /persistent/nixos-config/nix/scripts/admin/sops.sh init --rotate --yes
bash /persistent/nixos-config/nix/scripts/admin/sops.sh rekey
```

## 6. Git Secrets Guard

```bash
just hooks-enable
just guard-secrets
just guard-secrets-all
just status
```

```bash
bash /persistent/nixos-config/nix/scripts/admin/guard-secrets.sh
bash /persistent/nixos-config/nix/scripts/admin/guard-secrets.sh --all-tracked
```
