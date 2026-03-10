#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/install-nixos.sh <host> [--vm-test] [--execute]

Notes:
  - Prints the generated nixos-anywhere command by default.
  - Add --execute to run the destructive install.
EOF
}

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 1
fi

host=$1
shift

run_vm_test=false
execute=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vm-test)
      run_vm_test=true
      ;;
    --execute)
      execute=true
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

registry_value() {
  local field_name=$1

  nix eval --impure --raw --expr "
    let
      registry = builtins.fromTOML (builtins.readFile \"$repo_root/nix/registry/systems.toml\");
      hostSet = builtins.getAttr \"$host\" registry.nixos;
    in
    builtins.getAttr \"$field_name\" hostSet
  "
}

deploy_host=$(registry_value "deployHost")
deploy_user=$(registry_value "deployUser")

cmd=(nix run github:nix-community/nixos-anywhere --)
if [[ "$run_vm_test" == true ]]; then
  cmd+=(--vm-test)
fi
cmd+=(--flake "$repo_root#$host" "${deploy_user}@${deploy_host}")

printf 'Generated install command:\n'
printf '  %q' "${cmd[@]}"
printf '\n'

if [[ "$execute" != true ]]; then
  echo "Dry mode only. Re-run with --execute to perform the install."
  exit 0
fi

echo "About to run a destructive install for host '$host'." >&2
"${cmd[@]}"
