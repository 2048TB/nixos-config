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
  registryOwnedKeys = [
    "system"
    "formFactor"
    "profiles"
    "deployHost"
    "deployUser"
  ];
  conflictingRegistryKeys = builtins.filter
    (
      key:
      builtins.hasAttr key hostMyvars
      && builtins.hasAttr key hostRegistry
      && hostMyvars.${key} != hostRegistry.${key}
    )
    registryOwnedKeys;
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
  derivedCpuVendor = mylib.cpuVendorFromHardwareModules hostHardwareModuleNames;
  derivedGpuMode = mylib.gpuModeFromHardwareModules hostHardwareModuleNames;
  hostHardwareModules =
    map
      (moduleName:
        lib.attrByPath [ moduleName ] (throw "Unknown nixos-hardware module '${moduleName}' in ${hostDir}/hardware-modules.nix")
          nixos-hardware.nixosModules
      )
      hostHardwareModuleNames;

  resolvedMyvars = hostMyvars // hostRegistry // {
    hostname = name;
    gpuMode = hostMyvars.gpuMode or derivedGpuMode;
  };
  mainUser = resolvedMyvars.username;

  specialArgs = baseSpecialArgs // {
    myvars = resolvedMyvars;
    inherit mainUser derivedCpuVendor;
  };

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
assert lib.assertMsg
  (conflictingRegistryKeys == [ ])
  "Host ${hostDir}/vars.nix overrides registry-owned keys: ${lib.concatStringsSep ", " conflictingRegistryKeys}";
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
