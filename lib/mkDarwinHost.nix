{ lib }:
{ inputs
, mylib
, genSpecialArgs
, system
, name
, hostPath
, hostMyvars ? { }
, extraModules ? [ ]
, homeModules ? [ (mylib.relativeToRoot "home/darwin") ]
, hostHomeModulePath ? null
, ...
}:
let
  baseSpecialArgs = genSpecialArgs system;
  resolvedMyvars = baseSpecialArgs.myvars // { hostname = name; } // hostMyvars;
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

  resolvedHostHomeModulePath =
    if hostHomeModulePath != null
    then hostHomeModulePath
    else mylib.relativeToRoot "hosts/darwin/${name}/home.nix";

  darwinSystem = mylib.macosSystem {
    inherit inputs system mainUser specialArgs;
    modules = darwinBootstrapModules ++ [ hostPath ] ++ extraModules;
    homeModules = homeModules
      ++ lib.optionals (builtins.pathExists resolvedHostHomeModulePath) [ resolvedHostHomeModulePath ];
  };

  pkgs = import inputs.nixpkgs-darwin {
    inherit system;
    config.allowUnfree = true;
  };
in
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
