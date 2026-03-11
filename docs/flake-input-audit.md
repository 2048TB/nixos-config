# Flake Input Audit

当前策略：先审计，不先删。

生成命令：

```bash
bash nix/scripts/checks/unused-inputs.sh
```

初版审计结论：

| input | category | used by | keep | note |
|------|----------|---------|------|------|
| nixpkgs | core | `flake.nix` | yes | 主 Linux package set。 |
| nixpkgs-unstable | core | `nix/hosts/outputs/default.nix` | yes | 通过 `pkgsUnstable` 注入。 |
| nixpkgs-darwin | core | `nix/lib/mkDarwinHost.nix` | yes | Darwin package set。 |
| nix-darwin | core | `nix/lib/default.nix` | yes | Darwin system builder。 |
| nix-homebrew | darwin | `nix/lib/mkDarwinHost.nix` | yes | Darwin Homebrew bridge。 |
| homebrew-core | darwin | `nix/lib/mkDarwinHost.nix` | yes | Darwin tap source。 |
| homebrew-cask | darwin | `nix/lib/mkDarwinHost.nix` | yes | Darwin tap source。 |
| homebrew-bundle | darwin | `nix/lib/mkDarwinHost.nix` | yes | Darwin tap source。 |
| nixos-hardware | modules | `nix/lib/mkNixosHost.nix` | yes | NixOS hardware modules。 |
| rust-overlay | packages | `nix/lib/mkNixosHost.nix` | yes | Linux overlay。 |
| home-manager | core | `nix/lib/default.nix` | yes | NixOS/Darwin home bridge。 |
| noctalia | packages | `nix/home/linux/default.nix`, `nix/home/linux/desktop.nix` | yes | Linux desktop shell。 |
| lanzaboote | modules | `nix/lib/mkNixosHost.nix`, `nix/modules/core/boot.nix` | yes | Secure Boot module。 |
| nix-gaming | packages | `nix/lib/mkNixosHost.nix` | yes | Low-latency/gaming modules。 |
| preservation | modules | `nix/lib/mkNixosHost.nix`, `nix/modules/core/storage.nix` | yes | Persistence module。 |
| disko | modules | `nix/lib/mkNixosHost.nix`, `nix/scripts/admin/install-live.sh` | yes | Disk layout/install flow。 |
| sops-nix | modules | `nix/lib/mkNixosHost.nix` | yes | Secret management module。 |
| pre-commit-hooks | ci | `nix/hosts/outputs/x86_64-linux/default.nix` | yes | Dev shell / pre-commit checks。 |

后续删除规则：

- 先跑 `bash nix/scripts/checks/unused-inputs.sh`
- 再做针对性 `rg`
- 最后跑 `just flake-check` 和至少 1 个代表性 host build
