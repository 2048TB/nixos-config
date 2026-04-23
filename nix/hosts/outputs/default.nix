{ nixpkgs
, ...
}@inputs:
let
  inherit (nixpkgs) lib;
  mylib = import ../../lib { inherit lib; };
  mytheme = import ../../lib/theme.nix { inherit lib; };
  configRepoPath = "/persistent/nixos-config";
  exportedOverlays = import ../../overlays { inherit inputs; };

  genSpecialArgs =
    system:
    inputs
    // {
      inherit mylib mytheme configRepoPath;
      pkgsCherryStudio = import inputs.nixpkgs-cherry-studio {
        inherit system;
        config.allowUnfreePredicate = mylib.allowUnfreePredicate;
      };
      pkgsUnstable = import inputs.nixpkgs-unstable {
        inherit system;
        config.allowUnfreePredicate = mylib.allowUnfreePredicate;
      };
    };

  mkApp = pkgs: scriptName: description: scriptBody: {
    type = "app";
    program = "${(pkgs.writeShellScriptBin scriptName scriptBody)}/bin/${scriptName}";
    meta.description = description;
  };
  appRepoPreamble = ''
    set -euo pipefail
    repo="''${NIXOS_CONFIG_REPO:-$PWD}"
    if [ ! -f "$repo/flake.nix" ]; then
      echo "error: flake.nix not found in repo: $repo" >&2
      echo "hint: run from repo root or set NIXOS_CONFIG_REPO" >&2
      exit 1
    fi
    cd "$repo"
  '';

  args = {
    inherit inputs lib mylib genSpecialArgs mkApp appRepoPreamble;
    nixpkgsOverlays = [ exportedOverlays.default ];
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
  exportedNixosModules = import ../../modules/nixos;
  exportedPackages = {
    x86_64-linux = import ../../pkgs (
      import inputs.nixpkgs {
        system = "x86_64-linux";
        config.allowUnfreePredicate = mylib.allowUnfreePredicate;
        overlays = [ exportedOverlays.default ];
      }
    );
    aarch64-darwin = import ../../pkgs (
      import inputs.nixpkgs-darwin {
        system = "aarch64-darwin";
        config.allowUnfreePredicate = mylib.allowUnfreePredicate;
      }
    );
  };
in
{
  nixosConfigurations = lib.attrsets.mergeAttrsList (
    map (it: it.nixosConfigurations or { }) nixosSystemValues
  );

  darwinConfigurations = lib.attrsets.mergeAttrsList (
    map (it: it.darwinConfigurations or { }) darwinSystemValues
  );

  homeConfigurations = lib.attrsets.mergeAttrsList (
    map (it: it.homeConfigurations or { }) allSystemValues
  );

  apps = mylib.mergeRecursiveAttrsList (map (it: it.apps or { }) allSystemValues);
  checks = mylib.mergeRecursiveAttrsList (map (it: it.checks or { }) allSystemValues);
  devShells = mylib.mergeRecursiveAttrsList (map (it: it.devShells or { }) allSystemValues);
  formatter = mylib.mergeRecursiveAttrsList (map (it: it.formatter or { }) allSystemValues);
  overlays = exportedOverlays;
  packages = exportedPackages;
  nixosModules = exportedNixosModules;
}
