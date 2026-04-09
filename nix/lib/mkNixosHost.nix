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
, nixpkgsOverlays ? [ ]
, nixpkgsConfig ? { inherit (mylib) allowUnfreePredicate; }
, ...
}:
let
  hostRegistryLib = import ./host-registry.nix { inherit lib; };
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
  hostDir = "nix/hosts/nixos/${name}";
  registryPath = "nix/hosts/registry/systems.toml";
  registryState = hostRegistryLib.mkRegistryState {
    inherit hostRegistry hostMyvars;
  };
  hostDefaultPath = mylib.relativeToRoot "${hostDir}/default.nix";
  hostEntryPath =
    if hostPath != null then
      hostPath
    else if builtins.pathExists hostDefaultPath then
      hostDefaultPath
    else
      null;
  hostHardwarePath = mylib.relativeToRoot "${hostDir}/hardware.nix";
  hostHardwareModulesPath = mylib.relativeToRoot "${hostDir}/hardware-modules.nix";
  hostDiskoPath = mylib.relativeToRoot "${hostDir}/disko.nix";
  hostHomePath = mylib.relativeToRoot "${hostDir}/home.nix";
  hostHardwareModuleNames = import hostHardwareModulesPath;
  cpuVendor = mylib.cpuVendorFromHardwareModules hostHardwareModuleNames;
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
    inherit mainUser cpuVendor;
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
    ({ modulesPath, ... }: { imports = [ (modulesPath + "/installer/scan/not-detected.nix") ]; })
    preservation.nixosModules.default
    sops-nix.nixosModules.sops
    lanzaboote.nixosModules.lanzaboote
    nix-gaming.nixosModules.pipewireLowLatency
    nix-gaming.nixosModules.platformOptimizations
    disko.nixosModules.disko
  ]
  ++ lib.optionals (hostEntryPath != null) [ hostEntryPath ]
  ++ lib.optionals (hostEntryPath == null) [
    hostHardwarePath
    hostDiskoPath
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
assert hostRegistryLib.assertCommonRegistry
{
  inherit hostDir;
  inherit registryPath;
  hostName = "nixos.${name}";
  state = registryState;
};
assert mylib.assertRequiredNonEmptyStrings hostRegistry [
  "system"
] "${registryPath}[nixos.${name}]";
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
    cpuVendor
    specialArgs
    nixpkgsConfig
    nixpkgsOverlays
    nixosSystem
    pkgs
    ;
}
