{ lib }:
let
  nixosSystem =
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
    };

  macosSystem =
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
    };

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

  discoverHostNames =
    hostsRoot:
    let
      hostsDir = builtins.readDir hostsRoot;
    in
    builtins.filter
      (
        name:
        hostsDir.${name} == "directory"
        && builtins.pathExists (hostsRoot + "/${name}/default.nix")
      )
      (builtins.attrNames hostsDir);

  discoverHostNamesBy =
    hostsRoot: requiredFiles:
    let
      hostsDir = builtins.readDir hostsRoot;
    in
    builtins.filter
      (
        name:
        hostsDir.${name} == "directory"
        && builtins.all (file: builtins.pathExists (hostsRoot + "/${name}/${file}")) requiredFiles
      )
      (builtins.attrNames hostsDir);

  # Use paths relative to the repository root.
  relativeToRoot = lib.path.append ../.;

  # backward-compatible aliases
  mkNixosSystem = nixosSystem;
  mkMacosSystem = macosSystem;
}
