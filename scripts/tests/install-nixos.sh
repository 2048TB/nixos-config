#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
bash_bin=$(command -v bash)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/bin" "$tmpdir/scripts" "$tmpdir/nix/registry"
cp "$repo_root/scripts/install-nixos.sh" "$tmpdir/scripts/install-nixos.sh"
chmod +x "$tmpdir/scripts/install-nixos.sh"

cat >"$tmpdir/nix/registry/systems.toml" <<'EOF'
[nixos.demo]
platform = "nixos"
deployHost = "demo-host"
deployUser = "root"
EOF

cat >"$tmpdir/scripts/preflight-switch.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'preflight:%s\n' "$*" >>"${TEST_LOG}"
EOF
chmod +x "$tmpdir/scripts/preflight-switch.sh"

cat >"$tmpdir/bin/nix" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf 'nix:%s\n' "$*" >>"${TEST_LOG}"

case "$1" in
  eval)
    case "$*" in
      *deployHost*)
        printf 'demo-host'
        ;;
      *deployUser*)
        printf 'root'
        ;;
      *)
        echo "unexpected registry field query: $6" >&2
        exit 1
        ;;
    esac
    ;;
  run)
    exit 0
    ;;
  *)
    echo "unexpected nix command: $*" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$tmpdir/bin/nix"

log_file="$tmpdir/install.log"
PATH="$tmpdir/bin:$PATH" TEST_LOG="$log_file" "$bash_bin" "$tmpdir/scripts/install-nixos.sh" demo --execute >/dev/null

if ! grep -q '^preflight:nixos demo$' "$log_file"; then
  echo "install script did not invoke preflight" >&2
  cat "$log_file" >&2
  exit 1
fi

if ! grep -q "^nix:run ${tmpdir}#nixos-anywhere -- --flake ${tmpdir}#demo root@demo-host$" "$log_file"; then
  echo "install script did not use pinned nixos-anywhere app" >&2
  cat "$log_file" >&2
  exit 1
fi
