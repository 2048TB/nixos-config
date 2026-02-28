{ lib, mylib, myvars, inputs, system, ... }@args:
let
  hostsRoot = mylib.relativeToRoot "hosts/darwin";
  hostNames = mylib.discoverHostNames hostsRoot;

  mkHostData =
    name:
    let
      hostDir = "hosts/darwin/${name}";
      hostPath = mylib.relativeToRoot "${hostDir}/default.nix";
      hostVarsPath = mylib.relativeToRoot "${hostDir}/vars.nix";
      hostChecksPath = mylib.relativeToRoot "${hostDir}/checks.nix";
      hostMyvars = if builtins.pathExists hostVarsPath then import hostVarsPath else { };
      hostCtx = mylib.mkDarwinHost (args // {
        inherit name hostPath hostMyvars;
      });
      hostChecks =
        if builtins.pathExists hostChecksPath
        then import hostChecksPath hostCtx
        else { };
    in
    {
      darwinConfigurations.${hostCtx.name} = hostCtx.darwinSystem;
      checks.${hostCtx.system} = hostChecks;
    };

  data = builtins.listToAttrs (
    map
      (name: {
        inherit name;
        value = mkHostData name;
      })
      hostNames
  );
  dataWithoutPaths = builtins.attrValues data;

  darwinConfigurations =
    mylib.mergeRecursiveAttrsList (map (it: it.darwinConfigurations or { }) dataWithoutPaths);
  resolvedHostNames = builtins.attrNames darwinConfigurations;
  hostnameExpr = import ./tests/hostname/expr.nix { inherit lib darwinConfigurations; };
  hostnameExpected = import ./tests/hostname/expected.nix { hostNames = resolvedHostNames; };
  homeExpr = import ./tests/home/expr.nix { inherit lib darwinConfigurations; };
  homeExpected = import ./tests/home/expected.nix {
    hostNames = resolvedHostNames;
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
  mkApp = scriptName: description: scriptBody: {
    type = "app";
    program = "${(pkgs.writeShellScriptBin scriptName scriptBody)}/bin/${scriptName}";
    meta.description = description;
  };
  platformApps.${system} = {
    apply = mkApp "apply" "Apply Darwin host configuration (switch)" ''
      set -euo pipefail
      repo="''${NIXOS_CONFIG_REPO:-$PWD}"
      if [ ! -f "$repo/flake.nix" ] && [ -f "/persistent/nixos-config/flake.nix" ]; then
        repo="/persistent/nixos-config"
      fi
      cd "$repo"
      exec ${pkgs.just}/bin/just darwin-switch darwin_host="''${DARWIN_HOST:-zly-mac}"
    '';
    build-switch = mkApp "build-switch" "Build and switch Darwin host configuration" ''
      set -euo pipefail
      repo="''${NIXOS_CONFIG_REPO:-$PWD}"
      if [ ! -f "$repo/flake.nix" ] && [ -f "/persistent/nixos-config/flake.nix" ]; then
        repo="/persistent/nixos-config"
      fi
      cd "$repo"
      exec ${pkgs.just}/bin/just darwin-switch darwin_host="''${DARWIN_HOST:-zly-mac}"
    '';
    build = mkApp "build" "Build Darwin host configuration without switching" ''
      set -euo pipefail
      repo="''${NIXOS_CONFIG_REPO:-$PWD}"
      if [ ! -f "$repo/flake.nix" ] && [ -f "/persistent/nixos-config/flake.nix" ]; then
        repo="/persistent/nixos-config"
      fi
      cd "$repo"
      exec ${pkgs.just}/bin/just darwin-check darwin_host="''${DARWIN_HOST:-zly-mac}"
    '';
    clean = mkApp "clean" "Clean old generations" ''
      set -euo pipefail
      repo="''${NIXOS_CONFIG_REPO:-$PWD}"
      if [ ! -f "$repo/flake.nix" ] && [ -f "/persistent/nixos-config/flake.nix" ]; then
        repo="/persistent/nixos-config"
      fi
      cd "$repo"
      exec ${pkgs.just}/bin/just clean
    '';
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
assert lib.assertMsg (hostNames != [ ]) "No hosts found under hosts/darwin";
{
  inherit data;
  registeredHosts = resolvedHostNames;
  inherit darwinConfigurations evalTests;
  apps = platformApps;
  checks =
    mylib.mergeRecursiveAttrsList (
      (map (it: it.checks or { }) dataWithoutPaths)
      ++ [ evalTestChecks ]
    );
  devShells = mylib.mergeRecursiveAttrsList (map (it: it.devShells or { }) dataWithoutPaths);
  formatter = mylib.mergeRecursiveAttrsList (map (it: it.formatter or { }) dataWithoutPaths);
}
