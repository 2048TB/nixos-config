#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../../.." && pwd)"

if [ ! -f "$repo_root/.github/actions/setup-nix/action.yml" ]; then
  echo "expected composite Nix setup action" >&2
  exit 1
fi

if [ -f "$repo_root/.github/workflows/ci.yml" ]; then
  echo "expected heavy workflow to move from ci.yml to ci-heavy.yml" >&2
  exit 1
fi

if ! rg -n --fixed-strings 'uses: ./.github/actions/setup-nix' "$repo_root/.github/workflows/ci-light.yml" >/dev/null; then
  echo "expected ci-light.yml to use composite setup action" >&2
  exit 1
fi

if ! rg -n --fixed-strings 'uses: ./.github/actions/setup-nix' "$repo_root/.github/workflows/ci-heavy.yml" >/dev/null; then
  echo "expected ci-heavy.yml to use composite setup action" >&2
  exit 1
fi

if ! rg -n --fixed-strings 'bash nix/scripts/checks/registry-check.sh' "$repo_root/.github/workflows/ci-light.yml" >/dev/null; then
  echo "expected light CI to run registry-check.sh" >&2
  exit 1
fi

if ! rg -n --fixed-strings '.#nixosConfigurations.zly.config.system.build.toplevel' "$repo_root/.github/workflows/ci-light.yml" >/dev/null; then
  echo "expected light CI to build representative host zly" >&2
  exit 1
fi

for path in README.md docs/README.md docs/CI.md docs/ENV-USAGE.md docs/NIX-COMMANDS.md; do
  if [ ! -f "$repo_root/$path" ]; then
    echo "expected documentation entrypoint: $path" >&2
    exit 1
  fi
done

if ! rg -n --fixed-strings 'docs/README.md' "$repo_root/README.md" >/dev/null; then
  echo "expected root README to link to docs/README.md" >&2
  exit 1
fi

if ! rg -n --fixed-strings 'nix/hosts/README.md' "$repo_root/README.md" >/dev/null; then
  echo "expected root README to link to host docs" >&2
  exit 1
fi

if ! rg -n --fixed-strings 'docs/README.md' "$repo_root/docs/ENV-USAGE.md" >/dev/null; then
  echo "expected env usage guide to defer common operations to docs/README.md" >&2
  exit 1
fi

if ! rg -n --fixed-strings 'docs/README.md' "$repo_root/docs/NIX-COMMANDS.md" >/dev/null; then
  echo "expected command cheat sheet to defer routine operations to docs/README.md" >&2
  exit 1
fi
