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
  allowedRegistryKeys = [
    "system"
    "formFactor"
    "profiles"
    "deployEnabled"
    "deployHost"
    "deployUser"
    "deployPort"
    "configRepoPath"
  ];
  registryOwnedKeys = [
    "system"
    "formFactor"
    "profiles"
    "deployEnabled"
    "deployHost"
    "deployUser"
    "deployPort"
  ];
  unknownRegistryKeys = builtins.filter
    (key: !(builtins.elem key allowedRegistryKeys))
    (builtins.attrNames hostRegistry);
  conflictingRegistryKeys = builtins.filter
    (
      key:
      builtins.hasAttr key hostMyvars
      && builtins.hasAttr key hostRegistry
      && hostMyvars.${key} != hostRegistry.${key}
    )
    registryOwnedKeys;
  deployEnabled = hostRegistry.deployEnabled or true;
  deployHost = hostRegistry.deployHost or "";
  deployUser = hostRegistry.deployUser or "";
  deployPort = hostRegistry.deployPort or 22;
  hostDir = "nix/hosts/darwin/${name}";
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
assert lib.assertMsg
  (unknownRegistryKeys == [ ])
  "Host ${hostDir} registry entry has unsupported keys: ${lib.concatStringsSep ", " unknownRegistryKeys}";
assert lib.assertMsg
  (conflictingRegistryKeys == [ ])
  "Host ${hostDir}/vars.nix overrides registry-owned keys: ${lib.concatStringsSep ", " conflictingRegistryKeys}";
assert mylib.assertRequiredNonEmptyStrings hostRegistry [
  "system"
  "formFactor"
] "nix/hosts/registry/systems.toml[darwin.${name}]";
assert lib.assertMsg
  (builtins.isList (hostRegistry.profiles or null))
  "nix/hosts/registry/systems.toml[darwin.${name}].profiles must be a list";
assert lib.assertMsg
  (builtins.all builtins.isString (hostRegistry.profiles or [ ]))
  "nix/hosts/registry/systems.toml[darwin.${name}].profiles must only contain strings";
assert lib.assertMsg
  (builtins.isBool deployEnabled)
  "nix/hosts/registry/systems.toml[darwin.${name}].deployEnabled must be a boolean";
assert lib.assertMsg
  (builtins.isInt deployPort && deployPort > 0)
  "nix/hosts/registry/systems.toml[darwin.${name}].deployPort must be a positive integer";
assert lib.assertMsg
  (!deployEnabled || (deployHost != "" && deployUser != ""))
  "nix/hosts/registry/systems.toml[darwin.${name}] requires deployHost and deployUser when deployEnabled = true";
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
