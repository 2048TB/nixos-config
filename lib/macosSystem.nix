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
  inherit (inputs) nix-darwin nixpkgs-darwin home-manager;
in
nix-darwin.lib.darwinSystem {
  inherit system specialArgs;
  modules =
    modules
    ++ [
      (
        _:
        {
          nixpkgs.pkgs = import nixpkgs-darwin {
            inherit system;
            config.allowUnfree = true;
          };
        }
      )
      {
        # home-manager's nix-darwin bridge resolves home.homeDirectory from
        # users.users.<name>.home; ensure it is defined.
        users.users.${mainUser}.home = lib.mkDefault "/Users/${mainUser}";
      }
    ]
    ++ lib.optionals (homeModules != [ ]) [
      home-manager.darwinModules.home-manager
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "bak";
          extraSpecialArgs = specialArgs;
          users.${mainUser} = {
            imports = homeModules;
            # Keep Darwin HM user attrs defined at the assembly layer to avoid
            # null defaults leaking into eval-time checks.
            home = {
              username = lib.mkDefault mainUser;
              homeDirectory = lib.mkDefault "/Users/${mainUser}";
              stateVersion = lib.mkDefault "25.11";
            };
          };
        };
      }
    ];
}
