{ lib }:
{ inputs
, mylib
, genSpecialArgs
, system
, name
, hostPath ? null
, hostMyvars ? { }
, extraModules ? [ ]
, homeModules ? [ (mylib.relativeToRoot "nix/home/linux") ]
, nixpkgsOverlays ? [ inputs.rust-overlay.overlays.default ]
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
    agenix
    ;

  baseSpecialArgs = genSpecialArgs system;
  resolvedMyvars = hostMyvars // {
    hostname = name;
    configRepoPath = hostMyvars.configRepoPath or "/persistent/nixos-config";
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
    (mylib.relativeToRoot "nix/modules/hardware.nix")
    ({ modulesPath, ... }: { imports = [ (modulesPath + "/installer/scan/not-detected.nix") ]; })
    hostHardwarePath
    hostDiskoPath
    preservation.nixosModules.default
    agenix.nixosModules.default
    lanzaboote.nixosModules.lanzaboote
    nix-gaming.nixosModules.pipewireLowLatency
    nix-gaming.nixosModules.platformOptimizations
    disko.nixosModules.disko
  ]
  ++ nixosHardwareModules
  ++ lib.optionals (hostPath != null) [ hostPath ]
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
assert lib.assertMsg (builtins.pathExists hostHardwarePath) "Missing ${hostDir}/hardware.nix";
assert lib.assertMsg (builtins.pathExists hostDiskoPath) "Missing ${hostDir}/disko.nix";
assert lib.assertMsg (hostMyvars != { }) "Missing or empty ${hostDir}/vars.nix";
assert lib.assertMsg
  (mylib.hasNonEmptyString hostMyvars "username")
  "Invalid ${hostDir}/vars.nix: username must be a non-empty string";
assert lib.assertMsg
  (mylib.hasNonEmptyString hostMyvars "timezone")
  "Invalid ${hostDir}/vars.nix: timezone must be a non-empty string";
assert lib.assertMsg
  (mylib.hasNonEmptyString hostMyvars "systemStateVersion")
  "Invalid ${hostDir}/vars.nix: systemStateVersion must be a non-empty string";
assert lib.assertMsg
  (mylib.hasNonEmptyString hostMyvars "homeStateVersion")
  "Invalid ${hostDir}/vars.nix: homeStateVersion must be a non-empty string";
assert lib.assertMsg
  (mylib.hasNonEmptyString hostMyvars "diskDevice")
  "Invalid ${hostDir}/vars.nix: diskDevice must be a non-empty string";
assert lib.assertMsg
  (mylib.hasPositiveInt hostMyvars "swapSizeGb")
  "Invalid ${hostDir}/vars.nix: swapSizeGb must be a positive integer";
assert lib.assertMsg
  (mylib.hasNonEmptyString resolvedMyvars "configRepoPath")
  "Invalid ${hostDir}/vars.nix: configRepoPath must be a non-empty string";
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
