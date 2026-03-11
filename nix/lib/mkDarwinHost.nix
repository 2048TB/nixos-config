{ lib }:
{ inputs
, mylib
, genSpecialArgs
, system
, name
, hostPath ? null
, hostMyvars ? { }
, hostRegistry ? { }
, extraModules ? [ ]
, homeModules ? [ (mylib.relativeToRoot "nix/home/darwin") ]
, ...
}:
let
  hostRegistryLib = import ./host-registry.nix { inherit lib; };
  hostDir = "nix/hosts/darwin/${name}";
  registryPath = "nix/hosts/registry/systems.toml";
  registryState = hostRegistryLib.mkRegistryState {
    inherit hostRegistry hostMyvars;
  };
  hostHomePath = mylib.relativeToRoot "${hostDir}/home.nix";
  resolvedHomeModules = homeModules ++ lib.optionals (builtins.pathExists hostHomePath) [ hostHomePath ];

  baseSpecialArgs = genSpecialArgs system;
  resolvedMyvars = hostMyvars // hostRegistry // { hostname = name; };
  mainUser = resolvedMyvars.username;
  hasNixHomebrew = builtins.hasAttr "nix-homebrew" inputs;
  nixHomebrewTaps =
    (lib.optionalAttrs (builtins.hasAttr "homebrew-core" inputs) {
      "homebrew/homebrew-core" = inputs."homebrew-core";
    })
    // (lib.optionalAttrs (builtins.hasAttr "homebrew-cask" inputs) {
      "homebrew/homebrew-cask" = inputs."homebrew-cask";
    })
    // (lib.optionalAttrs (builtins.hasAttr "homebrew-bundle" inputs) {
      "homebrew/homebrew-bundle" = inputs."homebrew-bundle";
    });
  darwinBootstrapModules = lib.optionals hasNixHomebrew [
    inputs."nix-homebrew".darwinModules.nix-homebrew
    (
      { config, ... }:
      {
        nix-homebrew = {
          enable = true;
          user = mainUser;
          autoMigrate = true;
          mutableTaps = false;
          taps = nixHomebrewTaps;
        };

        # Keep nix-darwin taps aligned with nix-homebrew when taps are immutable.
        homebrew.taps = builtins.attrNames config.nix-homebrew.taps;
      }
    )
  ];

  specialArgs = baseSpecialArgs // {
    myvars = resolvedMyvars;
    inherit mainUser;
  };

  darwinSystem = mylib.macosSystem {
    inherit inputs system mainUser specialArgs;
    modules =
      darwinBootstrapModules
      ++ [ (mylib.relativeToRoot "nix/modules/darwin") ]
      ++ lib.optionals (hostPath != null) [ hostPath ]
      ++ extraModules;
    homeModules = resolvedHomeModules;
  };

  pkgs = import inputs.nixpkgs-darwin {
    inherit system;
    config.allowUnfreePredicate = mylib.allowUnfreePredicate;
  };
in
assert hostRegistryLib.assertCommonRegistry
{
  inherit hostDir hostRegistry;
  inherit registryPath;
  hostName = "darwin.${name}";
  state = registryState;
};
assert mylib.assertRequiredNonEmptyStrings hostRegistry [
  "system"
] "${registryPath}[darwin.${name}]";
assert mylib.assertNonEmptyAttrs hostMyvars "Missing or empty nix/hosts/darwin/${name}/vars.nix";
assert mylib.assertRequiredNonEmptyStrings hostMyvars [
  "username"
  "homeStateVersion"
  "timezone"
] "nix/hosts/darwin/${name}/vars.nix";
{
  inherit
    name
    system
    mainUser
    specialArgs
    darwinSystem
    pkgs
    ;
}
