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
                  stateVersion = lib.mkDefault (specialArgs.myvars.homeStateVersion or "25.11");
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
            (
              type == "directory"
              && builtins.pathExists (path + "/${name}/default.nix")
            )
            || (
              name != "default.nix"
              && lib.strings.hasSuffix ".nix" name
            )
          )
          (builtins.readDir path)
      )
    );

  mergeRecursiveAttrsList = attrsList: lib.foldl' lib.recursiveUpdate { } attrsList;

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

  roleFlags = myvars:
    let
      hostRoles = myvars.roles or [ "desktop" ];
      hasRole = role: builtins.elem role hostRoles;
      dockerMode = myvars.dockerMode or "rootless";
    in
    {
      inherit hostRoles hasRole dockerMode;
      enableMullvadVpn = myvars.enableMullvadVpn or (hasRole "vpn");
      enableLibvirtd = myvars.enableLibvirtd or (hasRole "virt");
      enableDocker = myvars.enableDocker or (hasRole "container");
      enableFlatpak = myvars.enableFlatpak or (hasRole "desktop");
      enableSteam = myvars.enableSteam or (hasRole "gaming");
      useRootfulDocker = dockerMode == "rootful";
      useRootlessDocker = dockerMode == "rootless";
    };

  kvmModulesForVendor = vendor:
    if vendor == "amd" then [ "kvm-amd" ]
    else if vendor == "intel" then [ "kvm-intel" ]
    else [ "kvm-amd" "kvm-intel" ];

  mkLogFilteredLauncher =
    pkgs: name: executable: filters:
    let
      mkSedDeleteExpr = pattern:
        let
          escapedPattern = lib.replaceStrings [ "/" ] [ "\\/" ] pattern;
        in
        "/${escapedPattern}/d";
      sedDeleteArgs =
        lib.concatMapStringsSep " \\\n"
          (pattern: "          -e ${lib.escapeShellArg (mkSedDeleteExpr pattern)}")
          filters;
    in
    pkgs.writeShellScriptBin name ''
            set -euo pipefail
            sedBin="${pkgs.gnused}/bin/sed"

            set +e
            ${executable} "$@" 2>&1 \
              | "$sedBin" -u -E \
      ${sedDeleteArgs}
              >&2
            status="''${PIPESTATUS[0]}"
            set -e
            exit "$status"
    '';
}
