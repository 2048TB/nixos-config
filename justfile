# Justfile for minimal NixOS repository operations

default:
    @just --list

host := ""
disk := "/dev/nvme0n1"
repo := env_var_or_default("NIXOS_CONFIG_REPO", justfile_directory())
nix_cmd := "nix --extra-experimental-features 'nix-command flakes'"

# ========== 安装 / Flake ==========

install:
    @if [ -z "{{host}}" ]; then echo "error: 需要指定主机. 用法: just host=zly disk=/dev/nvme0n1 install" >&2; exit 2; fi
    @bash {{repo}}/nix/scripts/admin/install-live.sh --host {{host}} --disk {{disk}} --repo {{repo}}

update:
    @bash {{repo}}/nix/scripts/admin/update-flake.sh {{repo}}

update-nixpkgs:
    @bash {{repo}}/nix/scripts/admin/update-flake.sh {{repo}} nixpkgs

upgrade:
    @if [ -z "{{host}}" ]; then echo "error: 需要指定主机. 用法: just host=zly upgrade" >&2; exit 2; fi
    @just update
    @just host={{host}} switch

show:
    @flake_repo="$(bash {{repo}}/nix/scripts/admin/print-flake-repo.sh {{repo}})"; {{nix_cmd}} flake show "path:$flake_repo"

metadata:
    @flake_repo="$(bash {{repo}}/nix/scripts/admin/print-flake-repo.sh {{repo}})"; {{nix_cmd}} flake metadata "path:$flake_repo"

hosts:
    @flake_repo="$(bash {{repo}}/nix/scripts/admin/print-flake-repo.sh {{repo}})"; {{nix_cmd}} eval "path:$flake_repo#nixosConfigurations" --apply builtins.attrNames

info:
    @flake_repo="$(bash {{repo}}/nix/scripts/admin/print-flake-repo.sh {{repo}})"; {{nix_cmd}} flake show "path:$flake_repo"
    @echo ""
    @echo "=== Flake 元数据 ==="
    @flake_repo="$(bash {{repo}}/nix/scripts/admin/print-flake-repo.sh {{repo}})"; {{nix_cmd}} flake metadata "path:$flake_repo"

use:
    @flake_repo="$(bash {{repo}}/nix/scripts/admin/print-flake-repo.sh {{repo}})"; echo ">>> entering filtered flake repo: $flake_repo"; cd "$flake_repo" && exec "${SHELL:-bash}" -l

# ========== 构建 / 切换 ==========

build:
    @if [ -z "{{host}}" ]; then echo "error: 需要指定主机. 用法: just host=zly build" >&2; exit 2; fi
    @flake_repo="$(bash {{repo}}/nix/scripts/admin/print-flake-repo.sh {{repo}})"; {{nix_cmd}} build "path:$flake_repo#nixosConfigurations.{{host}}.config.system.build.toplevel"

check:
    @if [ -z "{{host}}" ]; then echo "error: 需要指定主机. 用法: just host=zly check" >&2; exit 2; fi
    @flake_repo="$(bash {{repo}}/nix/scripts/admin/print-flake-repo.sh {{repo}})"; sudo nixos-rebuild dry-build --flake "path:$flake_repo#{{host}}"

dry-build:
    @if [ -z "{{host}}" ]; then echo "error: 需要指定主机. 用法: just host=zly dry-build" >&2; exit 2; fi
    @flake_repo="$(bash {{repo}}/nix/scripts/admin/print-flake-repo.sh {{repo}})"; {{nix_cmd}} build --dry-run "path:$flake_repo#nixosConfigurations.{{host}}.config.system.build.toplevel"

switch:
    @if [ -z "{{host}}" ]; then echo "error: 需要指定主机. 用法: just host=zly switch" >&2; exit 2; fi
    @flake_repo="$(bash {{repo}}/nix/scripts/admin/print-flake-repo.sh {{repo}})"; sudo nixos-rebuild switch --flake "path:$flake_repo#{{host}}"

boot:
    @if [ -z "{{host}}" ]; then echo "error: 需要指定主机. 用法: just host=zly boot" >&2; exit 2; fi
    @flake_repo="$(bash {{repo}}/nix/scripts/admin/print-flake-repo.sh {{repo}})"; sudo nixos-rebuild boot --flake "path:$flake_repo#{{host}}"

test:
    @if [ -z "{{host}}" ]; then echo "error: 需要指定主机. 用法: just host=zly test" >&2; exit 2; fi
    @flake_repo="$(bash {{repo}}/nix/scripts/admin/print-flake-repo.sh {{repo}})"; sudo nixos-rebuild test --flake "path:$flake_repo#{{host}}"

# ========== 清理 / 维护 ==========

gc:
    @sudo nix store gc

clean:
    @sudo nix-collect-garbage --delete-older-than 7d

clean-all:
    @sudo nix-collect-garbage -d

optimize:
    @sudo nix store optimise

# ========== Git / 安全 ==========

status:
    @git status

hooks-enable:
    git config core.hooksPath .githooks
    @echo "✓ 已启用 .githooks"

guard-secrets:
    @{{repo}}/nix/scripts/admin/guard-secrets.sh

# ========== Sops ==========

sops-init:
    @{{repo}}/nix/scripts/admin/sops.sh init

sops-init-create:
    @{{repo}}/nix/scripts/admin/sops.sh init --create

sops-init-rotate:
    @{{repo}}/nix/scripts/admin/sops.sh init --rotate

sops-recovery-init:
    @{{repo}}/nix/scripts/admin/sops.sh recovery-init

sops-host-key-add HOST PUB="/etc/ssh/ssh_host_ed25519_key.pub":
    @{{repo}}/nix/scripts/admin/sops.sh host-add '{{HOST}}' '{{PUB}}'

sops-recipients:
    @{{repo}}/nix/scripts/admin/sops.sh recipients

sops-rekey:
    @{{repo}}/nix/scripts/admin/sops.sh rekey

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
    @{{repo}}/nix/scripts/admin/sops.sh password-set '{{HASH}}'

ssh-key-set:
    @{{repo}}/nix/scripts/admin/sops.sh ssh-key-set
