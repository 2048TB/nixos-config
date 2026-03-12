#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../../.." && pwd)"
real_repo_root="$(realpath "$repo_root")"
schema="$repo_root/nix/hosts/registry/systems.schema.json"
registry="$repo_root/nix/hosts/registry/systems.toml"

if ! rg -n '"additionalProperties": false' "$schema" >/dev/null; then
  echo "expected strict additionalProperties in registry schema" >&2
  exit 1
fi

for field in desktopSession desktopProfile deployEnabled deployPort kind formFactor tags gpuVendors displays; do
  if ! rg -n "\"$field\"" "$schema" >/dev/null; then
    echo "expected $field in registry schema" >&2
    exit 1
  fi
done

for host in zky zly zzly; do
  if ! rg -n "^\[nixos\\.${host}\]" "$registry" >/dev/null; then
    echo "expected registry entry for nixos host $host" >&2
    exit 1
  fi
  if ! awk "/^\\[nixos\\.${host}\\]/{flag=1;next}/^\\[/{flag=0}flag" "$registry" | rg -n '^deployEnabled = true$' >/dev/null; then
    echo "expected deployEnabled=true for nixos host $host" >&2
    exit 1
  fi
  if ! awk "/^\\[nixos\\.${host}\\]/{flag=1;next}/^\\[/{flag=0}flag" "$registry" | rg -n '^deployPort = 22$' >/dev/null; then
    echo "expected deployPort=22 for nixos host $host" >&2
    exit 1
  fi
  if ! awk "/^\\[nixos\\.${host}\\]/{flag=1;next}/^\\[/{flag=0}flag" "$registry" | rg -n '^kind = "workstation"$' >/dev/null; then
    echo "expected workstation kind for nixos host $host" >&2
    exit 1
  fi
  if ! awk "/^\\[nixos\\.${host}\\]/{flag=1;next}/^\\[/{flag=0}flag" "$registry" | rg -n '^formFactor = "(desktop|laptop)"$' >/dev/null; then
    echo "expected formFactor for nixos host $host" >&2
    exit 1
  fi
  if ! awk "/^\\[nixos\\.${host}\\]/{flag=1;next}/^\\[/{flag=0}flag" "$registry" | rg -n '^desktopSession = true$' >/dev/null; then
    echo "expected desktopSession=true for nixos host $host" >&2
    exit 1
  fi
  if ! awk "/^\\[nixos\\.${host}\\]/{flag=1;next}/^\\[/{flag=0}flag" "$registry" | rg -n '^desktopProfile = "niri"$' >/dev/null; then
    echo "expected desktopProfile=niri for nixos host $host" >&2
    exit 1
  fi
  if ! awk "/^\\[nixos\\.${host}\\]/{flag=1;next}/^\\[/{flag=0}flag" "$registry" | rg -n '^tags = \[.*\]$' >/dev/null; then
    echo "expected tags for nixos host $host" >&2
    exit 1
  fi
  if awk "/^\\[nixos\\.${host}\\]/{flag=1;next}/^\\[/{flag=0}flag" "$registry" | rg -n '"(multi-monitor|hidpi)"' >/dev/null; then
    echo "expected derived display facts to stay out of tags for nixos host $host" >&2
    exit 1
  fi
  if ! awk "/^\\[nixos\\.${host}\\]/{flag=1;next}/^\\[/{flag=0}flag" "$registry" | rg -n '^gpuVendors = \[.*\]$' >/dev/null; then
    echo "expected gpuVendors for nixos host $host" >&2
    exit 1
  fi
  if ! rg -n "^\[nixos\\.${host}\]$|^\[\[nixos\\.${host}\\.displays\]\]$" "$registry" >/dev/null; then
    echo "expected displays metadata for nixos host $host" >&2
    exit 1
  fi
done

if ! rg -n '^\[darwin\.zly-mac\]' "$registry" >/dev/null; then
  echo "expected registry entry for darwin host zly-mac" >&2
  exit 1
fi

for expected_line in \
  'kind = "workstation"' \
  'formFactor = "laptop"' \
  'desktopSession = true' \
  'desktopProfile = "aqua"' \
  'tags = []' \
  'gpuVendors = []' \
  'displays = []'
do
  if ! awk '/^\[darwin\.zly-mac\]/{flag=1;next}/^\[/{flag=0}flag' "$registry" | rg -n --fixed-strings "$expected_line" >/dev/null; then
    echo "expected ${expected_line} for darwin host zly-mac" >&2
    exit 1
  fi
done

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
tmprepo="$tmpdir/repo"
mkdir -p "$tmprepo/nix/hosts/registry" "$tmpdir/bin" "$tmpdir/logs"
touch "$tmprepo/flake.nix"

cat >"$tmprepo/nix/hosts/registry/systems.toml" <<'EOF'
[nixos.zly]
system = "x86_64-linux"
desktopSession = true
desktopProfile = "niri"
kind = "workstation"
formFactor = "desktop"
tags = []
gpuVendors = ["amd", "nvidia"]
displays = []
deployEnabled = true
deployHost = "builder.internal"
deployUser = "admin"
deployPort = 2222

[nixos.zky]
system = "x86_64-linux"
desktopSession = true
desktopProfile = "niri"
kind = "workstation"
formFactor = "desktop"
tags = []
gpuVendors = ["nvidia"]
displays = []
deployEnabled = false
deployHost = "skip.internal"
deployUser = "root"
deployPort = 22
EOF

real_bash="$(command -v bash)"

printf '#!%s\n' "$real_bash" >"$tmpdir/bin/nix"
cat >>"$tmpdir/bin/nix" <<EOF
set -euo pipefail

args="\$*"
case "\$args" in
  *'path:${tmprepo}#nixosConfigurations'*)
    printf 'zly\nzky\n'
    ;;
  *.zly*'hostEntry.deployEnabled'*)
    printf 'true\n'
    ;;
  *.zky*'hostEntry.deployEnabled'*)
    printf 'false\n'
    ;;
  *.zly*'hostEntry.deployHost'*)
    printf 'builder.internal\n'
    ;;
  *.zky*'hostEntry.deployHost'*)
    printf 'skip.internal\n'
    ;;
  *.zly*'hostEntry.deployUser'*)
    printf 'admin\n'
    ;;
  *.zky*'hostEntry.deployUser'*)
    printf 'root\n'
    ;;
  *.zly*'hostEntry.deployPort'*)
    printf '2222\n'
    ;;
  *.zky*'hostEntry.deployPort'*)
    printf '22\n'
    ;;
  *)
    echo "unexpected nix invocation: \$args" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$tmpdir/bin/nix"

printf '#!%s\n' "$real_bash" >"$tmpdir/bin/nixos-rebuild"
cat >>"$tmpdir/bin/nixos-rebuild" <<'EOF'
set -euo pipefail
printf 'NIX_SSHOPTS=%s\n' "${NIX_SSHOPTS:-}" >>"$TEST_LOG_DIR/deploy.log"
printf 'CMD=%s\n' "$*" >>"$TEST_LOG_DIR/deploy.log"
EOF
chmod +x "$tmpdir/bin/nixos-rebuild"

TEST_LOG_DIR="$tmpdir/logs" PATH="$tmpdir/bin:$PATH" \
  bash "$repo_root/nix/scripts/admin/deploy-hosts.sh" --repo "$tmprepo" >"$tmpdir/stdout" 2>"$tmpdir/stderr"

if ! rg -n --fixed-strings 'target=admin@builder.internal' "$tmpdir/stdout" >/dev/null; then
  echo "expected deploy output for enabled host" >&2
  exit 1
fi

if ! rg -n --fixed-strings 'skip host=zky' "$tmpdir/stdout" >/dev/null; then
  echo "expected deploy script to skip disabled host" >&2
  exit 1
fi

if ! rg -n --fixed-strings 'NIX_SSHOPTS=-p 2222' "$tmpdir/logs/deploy.log" >/dev/null; then
  echo "expected deploy port to populate NIX_SSHOPTS" >&2
  exit 1
fi

if ! rg -n --fixed-strings 'CMD=switch --flake path:' "$tmpdir/logs/deploy.log" >/dev/null; then
  echo "expected nixos-rebuild invocation" >&2
  exit 1
fi

if rg -n --fixed-strings 'skip.internal' "$tmpdir/logs/deploy.log" >/dev/null; then
  echo "expected disabled host to be skipped before rebuild" >&2
  exit 1
fi

registry_assert_expr() {
  local host_registry_expr="$1"
  nix --extra-experimental-features 'nix-command flakes' eval --impure --expr "
    let
      flake = builtins.getFlake (toString $real_repo_root);
      lib = flake.inputs.nixpkgs.lib;
      hostRegistryLib = import $real_repo_root/nix/lib/host-registry.nix { inherit lib; };
      state = hostRegistryLib.mkRegistryState {
        hostMyvars = { };
        hostRegistry = $host_registry_expr;
      };
    in
    hostRegistryLib.assertCommonRegistry {
      registryPath = \"test\";
      hostDir = \"nix/hosts/nixos/test\";
      hostName = \"nixos.test\";
      inherit state;
    }
  " >/dev/null
}

if registry_assert_expr '{
  system = "x86_64-linux";
  desktopSession = false;
  desktopProfile = "niri";
  deployEnabled = true;
  deployHost = "test";
  deployUser = "root";
  deployPort = 22;
  kind = "workstation";
  formFactor = "desktop";
  tags = [];
  gpuVendors = [];
  displays = [];
}' 2>/dev/null; then
  echo "expected desktopSession=false + desktopProfile=niri to fail registry assertion" >&2
  exit 1
fi

if registry_assert_expr '{
  system = "x86_64-linux";
  desktopSession = true;
  desktopProfile = "niri";
  deployEnabled = true;
  deployHost = "test";
  deployUser = "root";
  deployPort = 22;
  kind = "workstation";
  formFactor = "desktop";
  tags = [];
  gpuVendors = [];
  displays = [
    { name = "DP-1"; primary = true; }
    { name = "HDMI-A-1"; primary = true; }
  ];
}' 2>/dev/null; then
  echo "expected multiple primary displays to fail registry assertion" >&2
  exit 1
fi

output="$(bash "$repo_root/nix/scripts/checks/unused-inputs.sh")"

if [[ "$output" != *"| input | category | used by | keep | note |"* ]]; then
  echo "expected markdown table header from unused-inputs.sh" >&2
  exit 1
fi

if [[ "$output" != *"| nixpkgs |"* ]]; then
  echo "expected nixpkgs row in input audit output" >&2
  exit 1
fi

if [[ "$output" != *"| pre-commit-hooks |"* ]]; then
  echo "expected pre-commit-hooks row in input audit output" >&2
  exit 1
fi

output="$(bash "$repo_root/nix/scripts/admin/repo-check.sh" --bad-flag 2>&1 || true)"

if [[ "$output" != *"Usage:"* ]]; then
  echo "expected usage output, got: $output" >&2
  exit 1
fi
