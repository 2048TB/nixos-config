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

info:
    @flake_repo="$({{repo}}/nix/scripts/admin/print-flake-repo.sh {{repo}})"; {{nix_cmd}} flake show "path:$flake_repo"
    @echo ""
    @echo "=== Flake 元数据 ==="
    @flake_repo="$({{repo}}/nix/scripts/admin/print-flake-repo.sh {{repo}})"; {{nix_cmd}} flake metadata "path:$flake_repo"

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
