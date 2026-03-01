{ nixpkgs
, ...
}@inputs:
let
  inherit (nixpkgs) lib;
  mylib = import ../../lib { inherit lib; };

  # Runtime cache settings for NixOS module consumption.
  # Keep in sync with flake.nix nixConfig for CLI users if needed.
  binaryCaches = {
    substituters = [
      "https://nix-community.cachix.org"
      "https://nixpkgs-wayland.cachix.org"
      "https://cache.garnix.io"
    ];
    trustedPublicKeys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    ];
  };

  sharedPortalConfig = {
    common = {
      default = [ "gnome" "gtk" ];
      "org.freedesktop.impl.portal.Settings" = [ "gtk" ];
      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
    };
    niri = {
      default = [ "gnome" "gtk" ];
      "org.freedesktop.impl.portal.Settings" = [ "gtk" ];
      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      "org.freedesktop.impl.portal.Inhibit" = [ "gtk" ];
    };
  };

  genSpecialArgs =
    system:
    inputs
    // {
      inherit mylib binaryCaches sharedPortalConfig;
      pkgsUnstable = import inputs.nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
    };

  args = {
    inherit inputs lib mylib genSpecialArgs;
  };

  nixosSystems = {
    x86_64-linux = import ./x86_64-linux (args // { system = "x86_64-linux"; });
  };
  darwinSystems = {
    aarch64-darwin = import ./aarch64-darwin (args // { system = "aarch64-darwin"; });
  };

  nixosSystemValues = builtins.attrValues nixosSystems;
  darwinSystemValues = builtins.attrValues darwinSystems;
  allSystemValues = nixosSystemValues ++ darwinSystemValues;
in
{
  nixosConfigurations = lib.attrsets.mergeAttrsList (
    map (it: it.nixosConfigurations or { }) nixosSystemValues
  );

  darwinConfigurations = lib.attrsets.mergeAttrsList (
    map (it: it.darwinConfigurations or { }) darwinSystemValues
  );

  apps = mylib.mergeRecursiveAttrsList (map (it: it.apps or { }) allSystemValues);
  checks = mylib.mergeRecursiveAttrsList (map (it: it.checks or { }) allSystemValues);
  devShells = mylib.mergeRecursiveAttrsList (map (it: it.devShells or { }) allSystemValues);
  formatter = mylib.mergeRecursiveAttrsList (map (it: it.formatter or { }) allSystemValues);
}
