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
  (unknownRegistryKeys == [ ])
  "Host ${hostDir} registry entry has unsupported keys: ${lib.concatStringsSep ", " unknownRegistryKeys}";
assert lib.assertMsg
  (conflictingRegistryKeys == [ ])
  "Host ${hostDir}/vars.nix overrides registry-owned keys: ${lib.concatStringsSep ", " conflictingRegistryKeys}";
assert mylib.assertRequiredNonEmptyStrings hostRegistry [
  "system"
  "formFactor"
] "nix/hosts/registry/systems.toml[nixos.${name}]";
assert lib.assertMsg
  (builtins.isList (hostRegistry.profiles or null))
  "nix/hosts/registry/systems.toml[nixos.${name}].profiles must be a list";
assert lib.assertMsg
  (builtins.all builtins.isString (hostRegistry.profiles or [ ]))
  "nix/hosts/registry/systems.toml[nixos.${name}].profiles must only contain strings";
assert lib.assertMsg
  (builtins.isBool deployEnabled)
  "nix/hosts/registry/systems.toml[nixos.${name}].deployEnabled must be a boolean";
assert lib.assertMsg
  (builtins.isInt deployPort && deployPort > 0)
  "nix/hosts/registry/systems.toml[nixos.${name}].deployPort must be a positive integer";
assert lib.assertMsg
  (!deployEnabled || (deployHost != "" && deployUser != ""))
  "nix/hosts/registry/systems.toml[nixos.${name}] requires deployHost and deployUser when deployEnabled = true";
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
