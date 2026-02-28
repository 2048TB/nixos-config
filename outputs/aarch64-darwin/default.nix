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

  darwinConfigurations =
    mylib.mergeRecursiveAttrsList (map (it: it.darwinConfigurations or { }) dataWithoutPaths);
  hostNames = builtins.attrNames darwinConfigurations;
  hostnameExpr = import ./tests/hostname/expr.nix { inherit lib darwinConfigurations; };
  hostnameExpected = import ./tests/hostname/expected.nix { inherit hostNames; };
  homeExpr = import ./tests/home/expr.nix { inherit lib darwinConfigurations; };
  homeExpected = import ./tests/home/expected.nix {
    inherit hostNames;
    mainUser = myvars.username;
  };
  evalTests = {
    hostname = hostnameExpr == hostnameExpected;
    home = homeExpr == homeExpected;
  };
  pkgs = import inputs.nixpkgs-darwin {
    inherit system;
    config.allowUnfree = true;
  };
  evalTestChecks.${system} = {
    evaltest-darwin-hostname = pkgs.runCommand "evaltest-darwin-hostname" { } ''
      if [ "${if evalTests.hostname then "1" else "0"}" != "1" ]; then
        echo "darwin hostname eval test failed" >&2
        exit 1
      fi
      touch "$out"
    '';
    evaltest-darwin-home = pkgs.runCommand "evaltest-darwin-home" { } ''
      if [ "${if evalTests.home then "1" else "0"}" != "1" ]; then
        echo "darwin home eval test failed" >&2
        exit 1
      fi
      touch "$out"
    '';
  };
in
assert lib.assertMsg (srcPaths != [ ]) "No host files found under outputs/aarch64-darwin/src";
{
  inherit data;
  registeredHosts = hostNames;
  inherit darwinConfigurations evalTests;
  checks =
    mylib.mergeRecursiveAttrsList (
      (map (it: it.checks or { }) dataWithoutPaths)
      ++ [ evalTestChecks ]
    );
  devShells = mylib.mergeRecursiveAttrsList (map (it: it.devShells or { }) dataWithoutPaths);
  formatter = mylib.mergeRecursiveAttrsList (map (it: it.formatter or { }) dataWithoutPaths);
}
