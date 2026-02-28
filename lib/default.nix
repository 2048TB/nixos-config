{ lib }:
let
  nixosSystem = import ./nixosSystem.nix { inherit lib; };
  macosSystem = import ./macosSystem.nix { inherit lib; };
  mkNixosHost = import ./mkNixosHost.nix { inherit lib; };
  mkDarwinHost = import ./mkDarwinHost.nix { inherit lib; };
in
{
  inherit nixosSystem macosSystem;
  inherit mkNixosHost mkDarwinHost;

  scanPaths =
    path:
    builtins.map (name: (path + "/${name}")) (
      builtins.attrNames (
        lib.attrsets.filterAttrs
          (
            name: type:
            (type == "directory")
            || (
              name != "default.nix"
              && lib.strings.hasSuffix ".nix" name
            )
          )
          (builtins.readDir path)
      )
    );

  mergeRecursiveAttrsList = attrsList: lib.foldl' lib.recursiveUpdate { } attrsList;

  # Use paths relative to the repository root.
  relativeToRoot = lib.path.append ../.;

  # backward-compatible aliases
  mkNixosSystem = nixosSystem;
  mkMacosSystem = macosSystem;
}
