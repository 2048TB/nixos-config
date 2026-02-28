{ lib, mylib, myvars, inputs, system, ... }@args:
let
  srcPaths = builtins.filter
    (path: lib.strings.hasSuffix ".nix" (builtins.baseNameOf (toString path)))
    (mylib.scanPaths ./src);
  data = builtins.listToAttrs (
    map
      (
        path:
        {
          name = lib.removeSuffix ".nix" (builtins.baseNameOf (toString path));
          value = import path args;
        }
      )
      srcPaths
  );
  dataWithoutPaths = builtins.attrValues data;
  nixosConfigurations =
    mylib.mergeRecursiveAttrsList (map (it: it.nixosConfigurations or { }) dataWithoutPaths);
  hostNames = builtins.attrNames nixosConfigurations;

  hostnameExpr = import ./tests/hostname/expr.nix { inherit lib nixosConfigurations; };
  hostnameExpected = import ./tests/hostname/expected.nix { inherit hostNames; };
  homeExpr = import ./tests/home/expr.nix { inherit lib nixosConfigurations; };
  homeExpected = import ./tests/home/expected.nix {
    inherit hostNames;
    mainUser = myvars.username;
  };
  evalTests = {
    hostname = hostnameExpr == hostnameExpected;
    home = homeExpr == homeExpected;
  };

  pkgs = import inputs.nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };
  evalTestChecks.${system} = {
    evaltest-hostname = pkgs.runCommand "evaltest-hostname" { } ''
      if [ "${if evalTests.hostname then "1" else "0"}" != "1" ]; then
        echo "hostname eval test failed" >&2
        exit 1
      fi
      touch "$out"
    '';
    evaltest-home = pkgs.runCommand "evaltest-home" { } ''
      if [ "${if evalTests.home then "1" else "0"}" != "1" ]; then
        echo "home eval test failed" >&2
        exit 1
      fi
      touch "$out"
    '';
  };

  preCommitCheck = inputs.pre-commit-hooks.lib.${system}.run {
    src = mylib.relativeToRoot ".";
    hooks = {
      nixpkgs-fmt.enable = true;
      statix.enable = true;
      deadnix.enable = true;
    };
  };

  platformChecks.${system}.pre-commit-check = preCommitCheck;

  defaultHost = if hostNames == [ ] then "zly" else builtins.head hostNames;
  platformDevShells.${system}.default = pkgs.mkShell {
    name = "nixos-config-dev";
    packages = with pkgs; [
      nix-tree
      nixpkgs-fmt
      statix
      deadnix
    ] ++ preCommitCheck.enabledPackages;
    shellHook = ''
      ${preCommitCheck.shellHook}
      echo "NixOS config dev shell"
      echo "nixos-rebuild switch --flake .#${defaultHost}"
      echo "nixos-rebuild test --flake .#${defaultHost}"
    '';
  };

  platformFormatter.${system} = pkgs.nixpkgs-fmt;
in
assert lib.assertMsg (srcPaths != [ ]) "No host files found under outputs/x86_64-linux/src";
{
  inherit data;
  registeredHosts = hostNames;
  inherit nixosConfigurations evalTests;
  checks =
    mylib.mergeRecursiveAttrsList (
      (map (it: it.checks or { }) dataWithoutPaths)
      ++ [
        evalTestChecks
        platformChecks
      ]
    );
  devShells =
    mylib.mergeRecursiveAttrsList (
      [ platformDevShells ] ++ map (it: it.devShells or { }) dataWithoutPaths
    );
  formatter =
    mylib.mergeRecursiveAttrsList (
      [ platformFormatter ] ++ map (it: it.formatter or { }) dataWithoutPaths
    );
}
