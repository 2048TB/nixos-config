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

  cpuVendor = resolvedMyvars.cpuVendor or "auto";
  nixosHardwareModules =
    [ nixos-hardware.nixosModules.common-pc-ssd ]
    ++ lib.optionals (cpuVendor == "amd") [ nixos-hardware.nixosModules.common-cpu-amd ]
    ++ lib.optionals (cpuVendor == "intel") [ nixos-hardware.nixosModules.common-cpu-intel ];

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
  hostDiskoPath = mylib.relativeToRoot "${hostDir}/disko.nix";
  hostModulesPath = mylib.relativeToRoot "${hostDir}/modules";
  hostHomePath = mylib.relativeToRoot "${hostDir}/home.nix";
  hostHomeModulesPath = mylib.relativeToRoot "${hostDir}/home-modules";

  discoveredHostModules =
    lib.optionals (builtins.pathExists hostModulesPath) (mylib.scanPaths hostModulesPath);
  discoveredHostHomeModules =
    (lib.optionals (builtins.pathExists hostHomePath) [ hostHomePath ])
    ++ (lib.optionals (builtins.pathExists hostHomeModulesPath) (mylib.scanPaths hostHomeModulesPath));
  resolvedHomeModules = homeModules ++ discoveredHostHomeModules;

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
  ++ nixosHardwareModules
  ++ discoveredHostModules
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
