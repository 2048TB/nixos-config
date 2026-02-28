{ self
, nixpkgs
, ...
}@inputs:
let
  inherit (nixpkgs) lib;
  mylib = import ../../lib { inherit lib; };
  myvars = import ../vars;

  flakeNixConfig = self.nixConfig or { };
  binaryCaches = {
    substituters = flakeNixConfig.extra-substituters or [ ];
    trustedPublicKeys = flakeNixConfig.extra-trusted-public-keys or [ ];
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
      inherit mylib myvars binaryCaches sharedPortalConfig;
      mainUser = myvars.username;
      pkgsUnstable = import inputs.nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
    };

  args = {
    inherit inputs lib mylib myvars genSpecialArgs;
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
