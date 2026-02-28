{ lib }:
{ inputs
, system
, specialArgs
, modules
, mainUser
, homeModules ? [ ]
, ...
}:
let
  inherit (inputs) nixpkgs home-manager;
in
nixpkgs.lib.nixosSystem {
  inherit system specialArgs;
  modules =
    modules
    ++ lib.optionals (homeModules != [ ]) [
      home-manager.nixosModules.home-manager
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "bak";
          extraSpecialArgs = specialArgs;
          users.${mainUser}.imports = homeModules;
        };
      }
    ];
}
