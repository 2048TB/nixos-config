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
just info
just show
just metadata
just hosts
just flake-check
just flake-check-full
just flake-check-exec
just registry-schema-check
just registry-meta-sync-check
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
just home-switch
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

## 5. 工具升级

```bash
just mise-upgrade
just tool-upgrade
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
just status
```

```bash
bash /persistent/nixos-config/nix/scripts/admin/guard-secrets.sh
bash /persistent/nixos-config/nix/scripts/admin/guard-secrets.sh --all-tracked
```

## 8. WireGuard VPN

当前 profiles：`wg-nqrvma`、`wg-vdrkye`、`wg-xafmcp`、`wg-hzplwt`、`wg-kqsjdn`。默认自启动 `wg-xafmcp`。profile、secret 文件名和 runtime path 使用 opaque 命名，不编码 provider、地区、城市、endpoint 编号或账号标识。kill switch 由 NixOS firewall 的 `iptables` backend 常驻管理，覆盖 host outbound 和 forwarded traffic，不依赖 provider `.conf` 自带 hook。

```bash
sudo vpn-status
sudo vpn-switch wg-vdrkye
sudo vpn-switch wg-xafmcp
sudo vpn-switch wg-nqrvma
sudo vpn-switch wg-hzplwt
sudo vpn-switch wg-kqsjdn
sudo vpn-select wg-xafmcp slot-a
sudo vpn-stop-all
```

`vpn-switch <profile>` 会先停止已加载的 `wg-quick-*` 服务和所有声明的 full-tunnel WireGuard profile，再启动目标 profile。`vpn-select <profile> <candidate>` 只更新该 profile 的 active symlink；如果当前 profile 正在运行，再执行一次 `vpn-switch <profile>` 应用新候选配置。activation 只在缺少 active path 时写入默认 active symlink；已有 symlink（即使当前 target 缺失）不会被覆盖。

`vpn-stop-all` 使用同一套停止路径，但不会关闭 kill switch；外网会继续被阻断，直到再次执行 `sudo vpn-switch <profile>`。kill switch 会放行 host outbound 的私网/链路本地地址，便于访问 LAN IP；公网 IPv4/IPv6 仍必须走 WireGuard。不要停止或禁用 NixOS firewall，否则 kill switch 也会被移除。
