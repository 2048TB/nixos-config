#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$script_dir/common.sh"

repo_root="$(enter_repo_root)"
cd "$repo_root"

# shellcheck disable=SC2016
# The Nix expression is single-quoted on purpose so `${...}` reaches `nix eval`.
nix --extra-experimental-features 'nix-command' eval --raw --impure --expr '
let
  hostMeta = (import ./nix/lib/host-meta.nix { }).hostMetaSchema;
  schema = builtins.fromJSON (builtins.readFile ./nix/hosts/registry/systems.schema.json);
  entry = schema."$defs".entry;
  sort = builtins.sort builtins.lessThan;
  assertEq = name: expected: actual:
    if sort expected == sort actual then
      true
    else
      builtins.throw "${name} mismatch. expected=${builtins.toJSON (sort expected)} actual=${builtins.toJSON (sort actual)}";
in
assert assertEq "registryOwnedKeys <-> schema.properties" hostMeta.registryOwnedKeys (builtins.attrNames entry.properties);
assert assertEq "requiredRegistryKeys <-> schema.required" hostMeta.requiredRegistryKeys entry.required;
assert assertEq "allowedDesktopProfiles <-> schema.desktopProfile.enum" hostMeta.allowedDesktopProfiles entry.properties.desktopProfile.enum;
assert assertEq "allowedKinds <-> schema.kind.enum" hostMeta.allowedKinds entry.properties.kind.enum;
assert assertEq "allowedFormFactors <-> schema.formFactor.enum" hostMeta.allowedFormFactors entry.properties.formFactor.enum;
assert assertEq "allowedHostTags <-> schema.tags.items.enum" hostMeta.allowedHostTags entry.properties.tags.items.enum;
assert assertEq "allowedGpuVendors <-> schema.gpuVendors.items.enum" hostMeta.allowedGpuVendors entry.properties.gpuVendors.items.enum;
"ok -- host metadata and schema are in sync"
'
