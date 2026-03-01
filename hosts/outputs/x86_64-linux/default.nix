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
  kernelExpr = import ./tests/kernel/expr.nix { inherit lib nixosConfigurations; };
  kernelExpected = import ./tests/kernel/expected.nix { inherit system; hostNames = resolvedHostNames; };
  platformExpr = import ./tests/platform/expr.nix { inherit lib nixosConfigurations; };
  platformExpected = import ./tests/platform/expected.nix { inherit system; hostNames = resolvedHostNames; };
  hostEvalTests = {
    hostname = hostnameExpr == hostnameExpected;
    home = homeExpr == homeExpected;
    kernel = kernelExpr == kernelExpected;
    platform = platformExpr == platformExpected;
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
  resolveNixosHostStrict = ''host="$("$repo/scripts/resolve-host.sh" nixos "$repo" "zly" --strict)"'';
  platformApps.${system} = {
    apply = mkApp "apply" "Apply Linux host configuration (switch)" ''
      ${appRepoPreamble}
      ${resolveNixosHostStrict}
      exec ${pkgs.just}/bin/just host="$host" switch
    '';
    build-switch = mkApp "build-switch" "Build and switch Linux host configuration" ''
      ${appRepoPreamble}
      ${resolveNixosHostStrict}
      exec ${pkgs.just}/bin/just host="$host" switch
    '';
    build = mkApp "build" "Dry-build Linux host configuration" ''
      ${appRepoPreamble}
      ${resolveNixosHostStrict}
      exec ${pkgs.just}/bin/just host="$host" check
    '';
    install = mkApp "install" "Install Linux host on Live ISO with disko+nixos-install" ''
      ${appRepoPreamble}
      ${resolveNixosHostStrict}
      exec ${pkgs.just}/bin/just host="$host" disk="''${NIXOS_DISK_DEVICE:-/dev/nvme0n1}" install-live
    '';
    clean = mkApp "clean" "Clean old generations" ''
      ${appRepoPreamble}
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
    evaltest-kernel = pkgs.runCommand "evaltest-kernel" { } ''
      if [ "${if hostEvalTests.kernel then "1" else "0"}" != "1" ]; then
        echo "kernel eval test failed" >&2
        exit 1
      fi
      touch "$out"
    '';
    evaltest-platform = pkgs.runCommand "evaltest-platform" { } ''
      if [ "${if hostEvalTests.platform then "1" else "0"}" != "1" ]; then
        echo "platform eval test failed" >&2
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
