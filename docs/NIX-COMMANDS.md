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
just update-nixos
just update-nixpkgs
just update-darwin
just show
just hosts
just flake-check
just flake-check-full
just pre-commit-check
just registry-schema-check
just registry-meta-sync-check
just self-check
just validate-local
just validate-local-full
just ml-shell
```

```bash
REPO=/persistent/nixos-config
flake_repo="$(bash "$REPO/nix/scripts/admin/print-flake-repo.sh" "$REPO")"
nix flake show "path:$flake_repo"
nix flake check --all-systems --no-build "path:$flake_repo"
nix flake check --all-systems "path:$flake_repo"
nix build "path:$flake_repo#checks.x86_64-linux.pre-commit-check"
nix build "path:$flake_repo#checks.x86_64-linux.format-sanity"
nix shell nixpkgs#check-jsonschema -c check-jsonschema --schemafile "$REPO/nix/hosts/registry/systems.schema.json" "$REPO/nix/hosts/registry/systems.toml"
bash "$REPO/nix/scripts/admin/host-meta-schema-sync.sh"
bash "$REPO/nix/scripts/admin/check-format-sanity.sh" --repo "$REPO"
nix eval "path:$flake_repo#nixosConfigurations" --apply builtins.attrNames
nix eval "path:$flake_repo#packages.x86_64-linux" --apply builtins.attrNames
nix eval "path:$flake_repo#overlays" --apply builtins.attrNames
nix eval "path:$flake_repo#nixosModules" --apply builtins.attrNames
```

## 3. 系统级命令

```bash
just host=zly build
just host=zly check
just host=zly switch
just home-switch
just host=zly boot
just host=zly test
just host=zly upgrade
```

## 4. 清理

```bash
just clean
just clean-all
just use
```

```bash
sudo nix store gc
sudo nix store optimise
```

## 5. 工具升级

```bash
just mise-upgrade
```

```bash
flake_repo="$(bash /persistent/nixos-config/nix/scripts/admin/print-flake-repo.sh /persistent/nixos-config)"
nix shell nixpkgs#nh -c nh os build "path:$flake_repo" -H zly
nix shell nixpkgs#nh -c nh os switch "path:$flake_repo" -H zly
nix shell nixpkgs#nh -c nh home switch "path:$flake_repo" -c "$(id -un)@$(hostname)"
nix shell nixpkgs#nh -c nh clean all --keep-since 30d --keep 15
nix shell nixpkgs#nh -c nh clean all --keep-since 0h --keep 0
```

`clean` 保留最近 30 天且至少 15 个 generation，和
`boot.loader.systemd-boot.configurationLimit = 15` 对齐。`clean-all` 会清理旧
profile generation，因此可能移除 boot menu 里的回滚入口；`/nix/store` 仍有缓存
并不代表旧 NixOS generation 仍可被 systemd-boot 选择。

## 6. `sops`

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

## 7. Git Secrets Guard

```bash
just hooks-enable
just guard-secrets
just guard-secrets-all
git check-ignore .keys/main.agekey
```

```bash
bash /persistent/nixos-config/nix/scripts/admin/guard-secrets.sh
bash /persistent/nixos-config/nix/scripts/admin/guard-secrets.sh --all-tracked
```

## 8. Mullvad VPN

启用 `"vpn"` role 的主机通过 `services.mullvad-vpn.package = pkgs.mullvad-vpn` 安装 Mullvad CLI/GUI 并启用 `mullvad-daemon`。连接、地区选择、恢复和 kill switch 交给 Mullvad app / daemon 管理。

```bash
mullvad status
mullvad account get
mullvad relay list
mullvad relay set location jp
mullvad lockdown-mode get
mullvad dns get
mullvad lan get
mullvad connect
mullvad disconnect
mullvad reconnect
wg --version
```

当前仓库保留 `wireguard-tools` 安装，但不再提供 WireGuard catalog、WireGuard encrypted config files、`vpn-list`、`vpn-status`、`vpn-switch`、`vpn-select` 或 `vpn-stop-all`。
