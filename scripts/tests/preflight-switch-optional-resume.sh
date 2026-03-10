#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
bash_bin=$(command -v bash)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/bin" "$tmpdir/scripts"
cp "$repo_root/scripts/preflight-switch.sh" "$tmpdir/scripts/preflight-switch.sh"
chmod +x "$tmpdir/scripts/preflight-switch.sh"

cat >"$tmpdir/scripts/generate-hosts-doc.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
chmod +x "$tmpdir/scripts/generate-hosts-doc.sh"

cat >"$tmpdir/bin/nix" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"${TEST_LOG}"

case "$1 $2" in
  "flake check")
    exit 0
    ;;
  "eval --raw")
    case "$3" in
      .#nixosConfigurations.testhost.config.networking.hostName)
        printf 'testhost'
        ;;
      .#nixosConfigurations.testhost.config.services.snapper.configs.root.SUBVOLUME)
        printf '/'
        ;;
      .#nixosConfigurations.testhost.config.boot.resumeDevice)
        echo "resumeDevice should not be queried when disabled" >&2
        exit 1
        ;;
      *)
        echo "unexpected nix eval --raw: $3" >&2
        exit 1
        ;;
    esac
    ;;
  "eval --json")
    case "$3" in
      .#nixosConfigurations.testhost.config.programs.nh.enable)
        printf 'true'
        ;;
      '.#nixosConfigurations.testhost.config.boot.resumeDevice != null')
        printf 'false'
        ;;
      *)
        echo "unexpected nix eval --json: $3" >&2
        exit 1
        ;;
    esac
    ;;
  "build --dry-run")
    case "$3" in
      .#nixosConfigurations.testhost.config.system.build.toplevel)
        exit 0
        ;;
      *)
        echo "unexpected nix build: $3" >&2
        exit 1
        ;;
    esac
    ;;
  *)
    echo "unexpected nix invocation: $*" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$tmpdir/bin/nix"

log_file="$tmpdir/nix.log"
PATH="$tmpdir/bin:$PATH" TEST_LOG="$log_file" "$bash_bin" "$tmpdir/scripts/preflight-switch.sh" nixos testhost >/dev/null

if grep -q 'resumeDevice)' "$log_file"; then
  echo "preflight unexpectedly queried resumeDevice" >&2
  cat "$log_file" >&2
  exit 1
fi
