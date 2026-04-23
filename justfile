# Justfile for minimal NixOS repository operations

default:
    @just --list

host := ""
disk := "/dev/nvme0n1"
repo := env_var_or_default("NIXOS_CONFIG_REPO", justfile_directory())
nix_cmd := "nix --extra-experimental-features 'nix-command flakes'"
nixos_update_inputs := "nixpkgs nixpkgs-unstable home-manager nixos-hardware river-kwm lanzaboote nix-gaming preservation disko sops-nix"
darwin_update_inputs := "nixpkgs-darwin nix-darwin nix-homebrew homebrew-core homebrew-cask homebrew-bundle"

# ========== 内部 helpers ==========

[private]
nixos-rebuild action:
    @if [ -z "{{host}}" ]; then echo "error: 需要指定主机. 用法: just host=<hostname> {{action}}" >&2; exit 2; fi
    @flake_repo="$(bash {{repo}}/nix/scripts/admin/print-flake-repo.sh {{repo}})"; sudo nixos-rebuild {{action}} --flake "path:$flake_repo#{{host}}"

[private]
nh-os action:
    @if [ -z "{{host}}" ]; then echo "error: 需要指定主机. 用法: just host=<hostname> nh-{{action}}" >&2; exit 2; fi
    @flake_repo="$(bash {{repo}}/nix/scripts/admin/print-flake-repo.sh {{repo}})"; {{nix_cmd}} shell nixpkgs#nh -c nh os {{action}} "path:$flake_repo" -H "{{host}}"

# ========== 安装 / Flake ==========

install:
    @if [ -z "{{host}}" ]; then echo "error: 需要指定主机. 用法: just host=zly disk=/dev/nvme0n1 install" >&2; exit 2; fi
    @bash {{repo}}/nix/scripts/admin/install-live.sh --host {{host}} --disk {{disk}} --repo {{repo}}

update:
    @bash {{repo}}/nix/scripts/admin/update-flake.sh {{repo}}

update-nixos:
    @bash {{repo}}/nix/scripts/admin/update-flake.sh {{repo}} {{nixos_update_inputs}}

update-nixpkgs:
    @bash {{repo}}/nix/scripts/admin/update-flake.sh {{repo}} nixpkgs

update-darwin:
    @bash {{repo}}/nix/scripts/admin/update-flake.sh {{repo}} {{darwin_update_inputs}}

upgrade:
    @if [ -z "{{host}}" ]; then echo "error: 需要指定主机. 用法: just host=zly upgrade" >&2; exit 2; fi
    @just repo={{repo}} update-nixos
    @just repo={{repo}} host={{host}} switch

show:
    @flake_repo="$(bash {{repo}}/nix/scripts/admin/print-flake-repo.sh {{repo}})"; {{nix_cmd}} flake show --all-systems "path:$flake_repo"

metadata:
    @flake_repo="$(bash {{repo}}/nix/scripts/admin/print-flake-repo.sh {{repo}})"; {{nix_cmd}} flake metadata "path:$flake_repo"

hosts:
    @flake_repo="$(bash {{repo}}/nix/scripts/admin/print-flake-repo.sh {{repo}})"; {{nix_cmd}} eval "path:$flake_repo#nixosConfigurations" --apply builtins.attrNames

info:
    #!/usr/bin/env bash
    set -euo pipefail
    flake_repo="$(bash {{repo}}/nix/scripts/admin/print-flake-repo.sh {{repo}})"
    {{nix_cmd}} flake show --all-systems "path:$flake_repo"
    echo ""
    echo "=== Flake 元数据 ==="
    {{nix_cmd}} flake metadata "path:$flake_repo"

flake-check:
    @flake_repo="$(bash {{repo}}/nix/scripts/admin/print-flake-repo.sh {{repo}})"; {{nix_cmd}} flake check --all-systems --no-build "path:$flake_repo"

flake-check-full:
    @flake_repo="$(bash {{repo}}/nix/scripts/admin/print-flake-repo.sh {{repo}})"; {{nix_cmd}} flake check --all-systems "path:$flake_repo"

flake-check-exec:
    @flake_repo="$(bash {{repo}}/nix/scripts/admin/print-flake-repo.sh {{repo}})"; {{nix_cmd}} build "path:$flake_repo#checks.x86_64-linux.pre-commit-check"

registry-schema-check:
    if command -v check-jsonschema >/dev/null 2>&1; then \
      check-jsonschema --schemafile "{{repo}}/nix/hosts/registry/systems.schema.json" "{{repo}}/nix/hosts/registry/systems.toml"; \
    else \
      nix shell nixpkgs#check-jsonschema -c check-jsonschema --schemafile "{{repo}}/nix/hosts/registry/systems.schema.json" "{{repo}}/nix/hosts/registry/systems.toml"; \
    fi

registry-meta-sync-check:
    @NIXOS_CONFIG_REPO={{repo}} {{repo}}/nix/scripts/admin/host-meta-schema-sync.sh

use:
    @flake_repo="$(bash {{repo}}/nix/scripts/admin/print-flake-repo.sh {{repo}})"; echo ">>> entering filtered flake repo: $flake_repo"; cd "$flake_repo" && exec "${SHELL:-bash}" -l

ml-shell:
    @flake_repo="$(bash {{repo}}/nix/scripts/admin/print-flake-repo.sh {{repo}})"; {{nix_cmd}} develop --option connect-timeout 60 "path:$flake_repo#ml"

# ========== 构建 / 切换 ==========

build: (nh-os "build")

check: (nixos-rebuild "dry-build")

dry-build:
    @if [ -z "{{host}}" ]; then echo "error: 需要指定主机. 用法: just host=<hostname> dry-build" >&2; exit 2; fi
    @flake_repo="$(bash {{repo}}/nix/scripts/admin/print-flake-repo.sh {{repo}})"; {{nix_cmd}} build --dry-run "path:$flake_repo#nixosConfigurations.{{host}}.config.system.build.toplevel"

home-switch:
    #!/usr/bin/env bash
    set -euo pipefail
    flake_repo="$(bash {{repo}}/nix/scripts/admin/print-flake-repo.sh {{repo}})"
    target_host="{{host}}"
    if [ -z "$target_host" ]; then
      target_host="$(hostname)"
    fi
    target_user="${HOME_MANAGER_USER:-$(id -un)}"
    {{nix_cmd}} shell nixpkgs#nh -c nh home switch "path:$flake_repo" -c "${target_user}@${target_host}"

switch: (nh-os "switch")
boot: (nixos-rebuild "boot")
test: (nixos-rebuild "test")

# ========== 清理 / 维护 ==========

gc:
    @sudo nix store gc

clean:
    @{{nix_cmd}} shell nixpkgs#nh -c nh clean all --keep-since 14d --keep 0

clean-all:
    @{{nix_cmd}} shell nixpkgs#nh -c nh clean all --keep-since 0h --keep 0

optimize:
    @sudo nix store optimise

mise-upgrade:
    @{{nix_cmd}} shell nixpkgs#mise -c mise upgrade --yes

tool-upgrade:
    @just repo={{repo}} mise-upgrade

# ========== Git / 安全 ==========

status:
    @git status

hooks-enable:
    git config core.hooksPath .githooks
    @echo "✓ 已启用 .githooks"

guard-secrets:
    @NIXOS_CONFIG_REPO={{repo}} {{repo}}/nix/scripts/admin/guard-secrets.sh

guard-secrets-all:
    @NIXOS_CONFIG_REPO={{repo}} {{repo}}/nix/scripts/admin/guard-secrets.sh --all-tracked

validate-local:
    @just repo={{repo}} guard-secrets-all
    @just repo={{repo}} registry-schema-check
    @just repo={{repo}} registry-meta-sync-check
    @just repo={{repo}} flake-check

validate-local-full:
    @just repo={{repo}} validate-local
    @just repo={{repo}} flake-check-full

# ========== Sops ==========

sops-init:
    @NIXOS_CONFIG_REPO={{repo}} {{repo}}/nix/scripts/admin/sops.sh init

sops-init-create:
    @NIXOS_CONFIG_REPO={{repo}} {{repo}}/nix/scripts/admin/sops.sh init --create

sops-init-rotate:
    @NIXOS_CONFIG_REPO={{repo}} {{repo}}/nix/scripts/admin/sops.sh init --rotate

sops-recovery-init:
    @NIXOS_CONFIG_REPO={{repo}} {{repo}}/nix/scripts/admin/sops.sh recovery-init

sops-host-key-add HOST PUB="/etc/ssh/ssh_host_ed25519_key.pub":
    @NIXOS_CONFIG_REPO={{repo}} {{repo}}/nix/scripts/admin/sops.sh host-add '{{HOST}}' '{{PUB}}'

sops-recipients:
    @NIXOS_CONFIG_REPO={{repo}} {{repo}}/nix/scripts/admin/sops.sh recipients

sops-rekey:
    @NIXOS_CONFIG_REPO={{repo}} {{repo}}/nix/scripts/admin/sops.sh rekey

password-hash:
    if command -v mkpasswd >/dev/null 2>&1; then \
      mkpasswd -m sha-512; \
    else \
      nix shell nixpkgs#mkpasswd -c mkpasswd -m sha-512; \
    fi

password-hashes:
    @echo ">>> userPasswordHash"
    @just password-hash
    @echo ""
    @echo ">>> rootPasswordHash"
    @just password-hash

password-set-hash HASH:
    @NIXOS_CONFIG_REPO={{repo}} {{repo}}/nix/scripts/admin/sops.sh password-set '{{HASH}}'

ssh-key-set:
    @NIXOS_CONFIG_REPO={{repo}} {{repo}}/nix/scripts/admin/sops.sh ssh-key-set
