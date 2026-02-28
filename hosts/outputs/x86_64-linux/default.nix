{ lib, mylib, inputs, system, ... }@args:
let
  hostsRoot = mylib.relativeToRoot "hosts/nixos";
  hostNames = mylib.discoverHostNamesBy hostsRoot [
    "hardware.nix"
    "disko.nix"
    "vars.nix"
  ];

  mkHostData =
    name:
    let
      hostDir = "hosts/nixos/${name}";
      hostPath = mylib.relativeToRoot "${hostDir}/host.nix";
      hostVarsPath = mylib.relativeToRoot "${hostDir}/vars.nix";
      hostChecksPath = mylib.relativeToRoot "${hostDir}/checks.nix";
      hostMyvars = import hostVarsPath;
      hostCtx = mylib.mkNixosHost (args // {
        inherit name hostMyvars;
        hostPath = if builtins.pathExists hostPath then hostPath else null;
      });
      hostChecks =
        if builtins.pathExists hostChecksPath
        then import hostChecksPath (hostCtx // { inherit (args) lib; })
        else { };
    in
    {
      nixosConfigurations.${hostCtx.name} = hostCtx.nixosSystem;
      checks.${hostCtx.system} = hostChecks;
      mainUsers.${hostCtx.name} = hostCtx.mainUser;
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
  nixosConfigurations =
    mylib.mergeRecursiveAttrsList (map (it: it.nixosConfigurations or { }) dataWithoutPaths);
  mainUsers = mylib.mergeRecursiveAttrsList (map (it: it.mainUsers or { }) dataWithoutPaths);
  resolvedHostNames = builtins.attrNames nixosConfigurations;

  hostnameExpr = import ./tests/hostname/expr.nix { inherit lib nixosConfigurations; };
  hostnameExpected = import ./tests/hostname/expected.nix { hostNames = resolvedHostNames; };
  homeExpr = import ./tests/home/expr.nix { inherit lib nixosConfigurations; };
  homeExpected = import ./tests/home/expected.nix { inherit mainUsers; };
  hostEvalTests = {
    hostname = hostnameExpr == hostnameExpected;
    home = homeExpr == homeExpected;
  };

  pkgs = import inputs.nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };
  mkApp = scriptName: description: scriptBody: {
    type = "app";
    program = "${(pkgs.writeShellScriptBin scriptName scriptBody)}/bin/${scriptName}";
    meta.description = description;
  };
  platformApps.${system} = {
    apply = mkApp "apply" "Apply Linux host configuration (switch)" ''
      set -euo pipefail
      repo="''${NIXOS_CONFIG_REPO:-$PWD}"
      if [ ! -f "$repo/flake.nix" ] && [ -f "/persistent/nixos-config/flake.nix" ]; then
        repo="/persistent/nixos-config"
      fi
      cd "$repo"
      exec ${pkgs.just}/bin/just host="''${NIXOS_HOST:-zly}" switch
    '';
    build-switch = mkApp "build-switch" "Build and switch Linux host configuration" ''
      set -euo pipefail
      repo="''${NIXOS_CONFIG_REPO:-$PWD}"
      if [ ! -f "$repo/flake.nix" ] && [ -f "/persistent/nixos-config/flake.nix" ]; then
        repo="/persistent/nixos-config"
      fi
      cd "$repo"
      exec ${pkgs.just}/bin/just host="''${NIXOS_HOST:-zly}" switch
    '';
    build = mkApp "build" "Dry-build Linux host configuration" ''
      set -euo pipefail
      repo="''${NIXOS_CONFIG_REPO:-$PWD}"
      if [ ! -f "$repo/flake.nix" ] && [ -f "/persistent/nixos-config/flake.nix" ]; then
        repo="/persistent/nixos-config"
      fi
      cd "$repo"
      exec ${pkgs.just}/bin/just host="''${NIXOS_HOST:-zly}" check
    '';
    install = mkApp "install" "Install Linux host on Live ISO with disko+nixos-install" ''
      set -euo pipefail
      repo="''${NIXOS_CONFIG_REPO:-$PWD}"
      if [ ! -f "$repo/flake.nix" ] && [ -f "/persistent/nixos-config/flake.nix" ]; then
        repo="/persistent/nixos-config"
      fi
      cd "$repo"
      exec ${pkgs.just}/bin/just host="''${NIXOS_HOST:-zly}" disk="''${NIXOS_DISK_DEVICE:-/dev/nvme0n1}" install-live
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
    evaltest-hostname = pkgs.runCommand "evaltest-hostname" { } ''
      if [ "${if hostEvalTests.hostname then "1" else "0"}" != "1" ]; then
        echo "hostname eval test failed" >&2
        exit 1
      fi
      touch "$out"
    '';
    evaltest-home = pkgs.runCommand "evaltest-home" { } ''
      if [ "${if hostEvalTests.home then "1" else "0"}" != "1" ]; then
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

  defaultHost = if resolvedHostNames == [ ] then "zly" else builtins.head resolvedHostNames;
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
assert lib.assertMsg (hostNames != [ ]) "No hosts found under hosts/nixos";
{
  inherit data;
  registeredHosts = resolvedHostNames;
  inherit nixosConfigurations;
  apps = platformApps;
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
