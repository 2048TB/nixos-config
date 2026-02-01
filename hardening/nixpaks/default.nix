{ pkgs, nixpak, ... }:
let
  callArgs = {
    mkNixPak = nixpak.lib.nixpak {
      inherit (pkgs) lib;
      inherit pkgs;
    };
  };
  wrapper = _pkgs: path: (_pkgs.callPackage path callArgs);
 in
{
  nixpkgs.overlays = [
    (_: super: {
      nixpaks = {
        telegram-desktop = wrapper super ./telegram-desktop.nix;
      };
    })
  ];
}
