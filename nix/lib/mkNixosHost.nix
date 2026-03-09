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
, homeModules ? [ (mylib.relativeToRoot "nix/home/linux") ]
, nixpkgsOverlays ? [
    inputs.rust-overlay.overlays.default
    (import (mylib.relativeToRoot "nix/overlays/telegram-desktop-fix.nix"))
  ]
, nixpkgsConfig ? { inherit (mylib) allowUnfreePredicate; }
, ...
}:
let
  inherit (inputs)
    nixpkgs
    nixos-hardware
    preservation
    lanzaboote
    nix-gaming
    disko
    sops-nix
    ;

  baseSpecialArgs = genSpecialArgs system;
  resolvedMyvars = hostRegistry // hostMyvars // {
    hostname = name;
    configRepoPath = hostMyvars.configRepoPath or hostRegistry.configRepoPath or "/persistent/nixos-config";
  };
  mainUser = resolvedMyvars.username;

  specialArgs = baseSpecialArgs // {
    myvars = resolvedMyvars;
    inherit mainUser;
  };

  hostDir = "nix/hosts/nixos/${name}";
  hostEntryPath =
    if hostPath != null then
      hostPath
    else
      mylib.relativeToRoot "${hostDir}/default.nix";
  hostHardwarePath = mylib.relativeToRoot "${hostDir}/hardware.nix";
  hostHardwareModulesPath = mylib.relativeToRoot "${hostDir}/hardware-modules.nix";
  hostDiskoPath = mylib.relativeToRoot "${hostDir}/disko.nix";
  hostHomePath = mylib.relativeToRoot "${hostDir}/home.nix";
  hostHardwareModuleNames = import hostHardwareModulesPath;
  hostHardwareModules =
    map
      (moduleName:
        lib.attrByPath [ moduleName ] (throw "Unknown nixos-hardware module '${moduleName}' in ${hostDir}/hardware-modules.nix")
          nixos-hardware.nixosModules
      )
      hostHardwareModuleNames;

  resolvedHomeModules = homeModules ++ lib.optionals (builtins.pathExists hostHomePath) [ hostHomePath ];

  nixpkgsModule = {
    nixpkgs = {
      config = nixpkgsConfig;
      overlays = nixpkgsOverlays;
    };
  };

  hostModules = [
    nixpkgsModule
    (mylib.relativeToRoot "nix/modules/core")
    (mylib.relativeToRoot "nix/modules/core/hardware.nix")
    ({ modulesPath, ... }: { imports = [ (modulesPath + "/installer/scan/not-detected.nix") ]; })
    hostEntryPath
    preservation.nixosModules.default
    sops-nix.nixosModules.sops
    lanzaboote.nixosModules.lanzaboote
    nix-gaming.nixosModules.pipewireLowLatency
    nix-gaming.nixosModules.platformOptimizations
    disko.nixosModules.disko
  ]
  ++ hostHardwareModules
  ++ extraModules;

  nixosSystem = mylib.nixosSystem {
    inherit inputs system specialArgs mainUser;
    modules = hostModules;
    homeModules = resolvedHomeModules;
  };

  pkgs = import nixpkgs {
    inherit system;
    config = nixpkgsConfig;
    overlays = nixpkgsOverlays;
  };
in
assert mylib.assertPathExists hostEntryPath "Missing ${hostDir}/default.nix";
assert mylib.assertPathExists hostHardwarePath "Missing ${hostDir}/hardware.nix";
assert mylib.assertPathExists hostHardwareModulesPath "Missing ${hostDir}/hardware-modules.nix";
assert mylib.assertPathExists hostDiskoPath "Missing ${hostDir}/disko.nix";
assert mylib.assertNonEmptyAttrs hostMyvars "Missing or empty ${hostDir}/vars.nix";
assert mylib.assertRequiredNonEmptyStrings hostMyvars [
  "username"
  "timezone"
  "systemStateVersion"
  "homeStateVersion"
  "diskDevice"
] "${hostDir}/vars.nix";
assert mylib.assertRequiredPositiveInts hostMyvars [ "swapSizeGb" ] "${hostDir}/vars.nix";
assert mylib.assertRequiredNonEmptyStrings resolvedMyvars [ "configRepoPath" ] "${hostDir}/vars.nix";
{
  inherit
    name
    system
    mainUser
    specialArgs
    nixpkgsConfig
    nixpkgsOverlays
    nixosSystem
    pkgs
    ;
}
