{ lib, ... }:
let
  coreDir = builtins.dirOf ./.;
  roleDir = coreDir + "/roles";
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
          (builtins.readDir roleDir).${name} == "regular"
          && lib.hasSuffix ".nix" name
        )
        (builtins.attrNames (builtins.readDir roleDir))
    ));
in
coreMixins ++ roleMixins
