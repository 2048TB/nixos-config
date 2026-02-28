{ lib }:
{ inputs
, mylib
, genSpecialArgs
, system
, name
, hostPath
, hostMyvars ? { }
, extraModules ? [ ]
, homeModules ? [ (mylib.relativeToRoot "home") ]
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

  hostHomeModulePath = mylib.relativeToRoot "hosts/nixos/${name}/home.nix";

  nixpkgsModule = {
    nixpkgs = {
      config = nixpkgsConfig;
      overlays = nixpkgsOverlays;
    };
  };

  hostModules = [
    hostPath
    nixpkgsModule
    preservation.nixosModules.default
    lanzaboote.nixosModules.lanzaboote
    nix-gaming.nixosModules.pipewireLowLatency
    nix-gaming.nixosModules.platformOptimizations
    disko.nixosModules.disko
  ] ++ extraModules;

  nixosSystem = mylib.nixosSystem {
    inherit inputs system specialArgs mainUser;
    modules = hostModules;
    homeModules = homeModules
      ++ lib.optionals (builtins.pathExists hostHomeModulePath) [ hostHomeModulePath ];
  };

  pkgs = import nixpkgs {
    inherit system;
    config = nixpkgsConfig;
    overlays = nixpkgsOverlays;
  };
in
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
