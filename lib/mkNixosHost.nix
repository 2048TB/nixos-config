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
, nixpkgsConfig ? { allowUnfree = true; }
, ...
}:
let
  inherit (inputs)
    nixpkgs
    preservation
    lanzaboote
    nix-gaming
    disko
    ;

  baseSpecialArgs = genSpecialArgs system;
  resolvedMyvars = baseSpecialArgs.myvars // { hostname = name; } // hostMyvars;
  mainUser = resolvedMyvars.username;

  specialArgs = baseSpecialArgs // {
    myvars = resolvedMyvars;
    inherit mainUser;
  };

  hostDir = "hosts/nixos/${name}";
  hostHardwarePath = mylib.relativeToRoot "${hostDir}/hardware.nix";
  hostDiskoPath = mylib.relativeToRoot "${hostDir}/disko.nix";

  nixpkgsModule = {
    nixpkgs = {
      config = nixpkgsConfig;
      overlays = nixpkgsOverlays;
    };
  };

  hostModules = [
    nixpkgsModule
    (mylib.relativeToRoot "nix/modules/system.nix")
    (mylib.relativeToRoot "nix/modules/hardware.nix")
    ({ modulesPath, ... }: { imports = [ (modulesPath + "/installer/scan/not-detected.nix") ]; })
    hostHardwarePath
    hostDiskoPath
    preservation.nixosModules.default
    lanzaboote.nixosModules.lanzaboote
    nix-gaming.nixosModules.pipewireLowLatency
    nix-gaming.nixosModules.platformOptimizations
    disko.nixosModules.disko
  ]
  ++ lib.optionals (hostPath != null) [ hostPath ]
  ++ extraModules;

  nixosSystem = mylib.nixosSystem {
    inherit inputs system specialArgs mainUser;
    modules = hostModules;
    inherit homeModules;
  };

  pkgs = import nixpkgs {
    inherit system;
    config = nixpkgsConfig;
    overlays = nixpkgsOverlays;
  };
in
assert lib.assertMsg (builtins.pathExists hostHardwarePath) "Missing ${hostDir}/hardware.nix";
assert lib.assertMsg (builtins.pathExists hostDiskoPath) "Missing ${hostDir}/disko.nix";
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
