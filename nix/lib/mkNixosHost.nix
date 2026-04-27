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
  resolvedGpuMode = hostMyvars.gpuMode or derivedGpuMode;
  registryState = hostRegistryLib.mkRegistryState {
    inherit hostRegistry;
    hostMyvars = hostMyvars // {
      gpuMode = resolvedGpuMode;
    };
  };
  hostHardwareModules =
    map
      (moduleName:
        lib.attrByPath [ moduleName ] (throw "Unknown nixos-hardware module '${moduleName}' in ${hostDir}/hardware-modules.nix")
          nixos-hardware.nixosModules
      )
      hostHardwareModuleNames;

  resolvedMyvars = hostMyvars // hostRegistry // {
    hostname = name;
    gpuMode = resolvedGpuMode;
  };
  roleFlags = mylib.roleFlags resolvedMyvars;
  hasDesktopSession = registryState.desktopSession;
  secureBootCfg = resolvedMyvars.secureBoot or { };
  enableSecureBoot = secureBootCfg.enable or false;
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
    # 这些模块主要声明 options；实际启用由 core/host 配置控制。
    # preservation 与 disko 是当前 NixOS host 布局契约，sops-nix 被 core/secrets.nix 消费。
    preservation.nixosModules.default
    sops-nix.nixosModules.sops
    disko.nixosModules.disko
  ]
  ++ lib.optionals hasDesktopSession [
    # pipewireLowLatency only defines the lowLatency option used by desktop audio;
    # services.pipewire.lowLatency still controls whether it is enabled.
    nix-gaming.nixosModules.pipewireLowLatency
  ]
  ++ lib.optionals roleFlags.enableSteam [
    nix-gaming.nixosModules.platformOptimizations
  ]
  ++ lib.optionals enableSecureBoot [
    # Import lanzaboote only for hosts that explicitly opt in via vars.nix.
    lanzaboote.nixosModules.lanzaboote
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
