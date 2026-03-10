#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/check-resume.sh <nixos-host>
EOF
}

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 1
fi

host=$1
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

cd "$repo_root"

resume_device=$(nix eval --raw ".#nixosConfigurations.${host}.config.boot.resumeDevice")
resume_offset=$(
  nix eval --impure --raw --expr "
    let
      flake = builtins.getFlake \"$repo_root\";
      params = flake.nixosConfigurations.${host}.config.boot.kernelParams;
      matches = builtins.filter (p: builtins.match \"resume_offset=.*\" p != null) params;
    in
    if matches == [ ] then \"\" else builtins.head matches
  "
)

if [[ -z "$resume_device" || -z "$resume_offset" ]]; then
  echo "resume is not fully configured for host: $host" >&2
  exit 1
fi

echo "configured resumeDevice: $resume_device"
echo "configured ${resume_offset}"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "runtime checks skipped: current system is not Linux"
  exit 0
fi

current_host=$(hostname -s || true)
if [[ "$current_host" != "$host" ]]; then
  echo "runtime checks skipped: current host is '$current_host', target is '$host'"
  exit 0
fi

root_source=$(findmnt -no SOURCE / || true)
cmdline_offset=$(tr ' ' '\n' </proc/cmdline | grep '^resume_offset=' || true)
power_states=$(tr ' ' '\n' </sys/power/state 2>/dev/null || true)

echo "runtime root source: ${root_source:-<unknown>}"
echo "runtime ${cmdline_offset:-resume_offset=<missing>}"

if [[ -n "$root_source" && "$root_source" != "$resume_device" ]]; then
  echo "runtime root source does not match configured resumeDevice" >&2
  exit 1
fi

if [[ "$cmdline_offset" != "$resume_offset" ]]; then
  echo "runtime kernel cmdline does not match configured resume_offset" >&2
  exit 1
fi

if ! grep -qx 'disk' <<<"$power_states"; then
  echo "runtime power states do not advertise hibernation ('disk')" >&2
  exit 1
fi

echo "resume runtime checks passed for ${host}"
