{ lib, ... }:
let
  coreDir = builtins.dirOf ./.;
  roleDir = coreDir + "/roles";
  roleEntries = builtins.readDir roleDir;
  coreMixins = map
    (name: coreDir + "/${name}")
    [
      "assertions.nix"
      "boot.nix"
      "desktop.nix"
      "hardware.nix"
      "nix-settings.nix"
      "secrets.nix"
      "security.nix"
      "services.nix"
      "storage.nix"
    ];
  roleMixins = map
    (name: roleDir + "/${name}")
    (builtins.sort builtins.lessThan (
      builtins.filter
        (
          name:
          roleEntries.${name} == "regular"
          && lib.hasSuffix ".nix" name
        )
        (builtins.attrNames roleEntries)
    ));
in
coreMixins ++ roleMixins
