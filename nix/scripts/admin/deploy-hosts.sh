#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/common.sh"

usage() {
  cat <<'EOF'
usage:
  deploy-hosts.sh [--hosts <csv>] [--repo <path>] [-- <extra nixos-rebuild args>]

examples:
  deploy-hosts.sh
  deploy-hosts.sh --hosts zly,zky
  deploy-hosts.sh --hosts zly -- --build-host zly --fast
EOF
}

hosts_csv=""
repo="${NIXOS_CONFIG_REPO:-$PWD}"
extra_args=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --hosts)
      hosts_csv="${2:-}"
      shift 2
      ;;
    --repo)
      repo="${2:-}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --)
      shift
      extra_args+=("$@")
      break
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

repo="$(resolve_repo_path "$repo")"

list_hosts() {
  nix eval --raw "path:${repo}#nixosConfigurations" \
    --apply 'cfgs: builtins.concatStringsSep "\n" (builtins.attrNames cfgs)'
}

get_registry_field() {
  local host="$1"
  local field="$2"
  local mode="${3:-raw}"
  local flag="--raw"

  if [ "$mode" = "json" ]; then
    flag="--json"
  fi

  nix eval --impure "$flag" --expr "
    let
      registry = builtins.fromTOML (builtins.readFile \"${repo}/nix/hosts/registry/systems.toml\");
      hostEntry = (registry.nixos or {}).${host} or {};
    in
    hostEntry.${field} or \"\"
  " 2>/dev/null || true
}

declare -a hosts=()
if [ -n "$hosts_csv" ]; then
  IFS=',' read -r -a raw_hosts <<<"$hosts_csv"
  for h in "${raw_hosts[@]}"; do
    h="$(printf '%s' "$h" | xargs)"
    [ -n "$h" ] || continue
    if ! is_valid_host_name "$h"; then
      echo "error: invalid host name: '$h'" >&2
      exit 2
    fi
    hosts+=("$h")
  done
else
  while IFS= read -r h; do
    [ -n "$h" ] || continue
    hosts+=("$h")
  done < <(list_hosts)
fi

if [ "${#hosts[@]}" -eq 0 ]; then
  echo "error: no nixos hosts found to deploy" >&2
  exit 1
fi

echo ">>> repo=$repo"
echo ">>> hosts=${hosts[*]}"

for host in "${hosts[@]}"; do
  deploy_enabled="$(get_registry_field "$host" "deployEnabled" "json")"
  target_host="$(get_registry_field "$host" "deployHost")"
  target_user="$(get_registry_field "$host" "deployUser")"
  target_port="$(get_registry_field "$host" "deployPort" "json")"

  if [ -z "$deploy_enabled" ] || [ "$deploy_enabled" = "null" ]; then
    deploy_enabled="true"
  fi
  if [ "$deploy_enabled" = "false" ]; then
    echo ""
    echo "=== skip host=${host} (deployEnabled=false) ==="
    continue
  fi

  if [ -z "$target_host" ]; then
    target_host="$host"
  fi
  if [ -z "$target_user" ]; then
    target_user="root"
  fi
  if [ -z "$target_port" ] || [ "$target_port" = "null" ]; then
    target_port="22"
  fi

  echo ""
  echo "=== deploy host=${host} target=${target_user}@${target_host} port=${target_port} ==="

  cmd=(
    nixos-rebuild
    switch
    --flake
    "path:${repo}#${host}"
    --target-host
    "${target_user}@${target_host}"
    --use-remote-sudo
    --use-substitutes
  )
  if [ "${#extra_args[@]}" -gt 0 ]; then
    cmd+=("${extra_args[@]}")
  fi

  NIX_SSHOPTS="${NIX_SSHOPTS:+$NIX_SSHOPTS }-p ${target_port}" "${cmd[@]}"
done
