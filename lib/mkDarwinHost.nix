{ lib }:
{ inputs
, mylib
, genSpecialArgs
, system
, name
, hostPath ? null
, hostMyvars ? { }
, extraModules ? [ ]
, homeModules ? [ (mylib.relativeToRoot "nix/home/darwin") ]
, ...
}:
let
  baseSpecialArgs = genSpecialArgs system;
  resolvedMyvars = hostMyvars // { hostname = name; };
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

  sharedDarwinDefaults = {
    system.primaryUser = mainUser;
    homebrew = {
      enable = true;
      onActivation = {
        autoUpdate = false;
        upgrade = false;
        cleanup = "none";
      };
    };
  };

  darwinSystem = mylib.macosSystem {
    inherit inputs system mainUser specialArgs;
    modules =
      darwinBootstrapModules
      ++ [ sharedDarwinDefaults ]
      ++ lib.optionals (hostPath != null) [ hostPath ]
      ++ extraModules;
    inherit homeModules;
  };

  pkgs = import inputs.nixpkgs-darwin {
    inherit system;
    config.allowUnfree = true;
  };
in
assert lib.assertMsg (hostMyvars != { }) "Missing or empty hosts/darwin/${name}/vars.nix";
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
