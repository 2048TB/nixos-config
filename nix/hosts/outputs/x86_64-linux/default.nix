{ lib, mylib, inputs, system, mkApp, appRepoPreamble, ... }@args:
let
  hostsRoot = mylib.relativeToRoot "nix/hosts/nixos";
  hostNames = mylib.discoverHostNamesBy hostsRoot [
    "hardware.nix"
    "disko.nix"
    "vars.nix"
  ];
  hostNamePattern = "^[A-Za-z0-9][A-Za-z0-9_-]*$";
  invalidHostNames = mylib.namesNotMatching hostNamePattern hostNames;

  mkHostData =
    name:
    let
      hostDir = "nix/hosts/nixos/${name}";
      hostPath = mylib.relativeToRoot "${hostDir}/host.nix";
      hostVarsPath = mylib.relativeToRoot "${hostDir}/vars.nix";
      hostChecksPath = mylib.relativeToRoot "${hostDir}/checks.nix";
      hostMyvars = import hostVarsPath;
      hostCtx = mylib.mkNixosHost (args // {
        inherit name hostMyvars;
        hostPath = mylib.pathIfExists hostPath;
      });
      hostChecks = mylib.importIfExists hostChecksPath (hostCtx // { inherit (args) lib mylib; });
    in
    mylib.mkHostDataEntry {
      configAttrName = "nixosConfigurations";
      hostSystemAttr = "nixosSystem";
      inherit hostCtx hostChecks;
    };

  data = mylib.mapNamesToAttrs hostNames mkHostData;
  dataWithoutPaths = builtins.attrValues data;
  nixosConfigurations = mylib.mergeAttrFromList "nixosConfigurations" dataWithoutPaths;
  mainUsers = mylib.mergeAttrFromList "mainUsers" dataWithoutPaths;
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
    config.allowUnfreePredicate = mylib.allowUnfreePredicate;
  };
  mkAppLocal = mkApp pkgs;
  mkEvalCheck =
    { name, ok, message }:
    pkgs.runCommand name { } ''
      if [ "${if ok then "1" else "0"}" != "1" ]; then
        echo "${message}" >&2
        exit 1
      fi
      touch "$out"
    '';
  evalCheckSpecs = [
    {
      name = "evaltest-hostname";
      ok = hostEvalTests.hostname;
      message = "hostname eval test failed";
    }
    {
      name = "evaltest-home";
      ok = hostEvalTests.home;
      message = "home eval test failed";
    }
    {
      name = "evaltest-kernel";
      ok = hostEvalTests.kernel;
      message = "kernel eval test failed";
    }
    {
      name = "evaltest-platform";
      ok = hostEvalTests.platform;
      message = "platform eval test failed";
    }
  ];
  resolveNixosHostStrict = ''host="$("$repo/nix/scripts/admin/resolve-host.sh" nixos "$repo" "${builtins.head resolvedHostNames}" --strict)"'';
  platformApps.${system} = {
    apply = mkAppLocal "apply" "Apply Linux host configuration (switch)" ''
      ${appRepoPreamble}
      ${resolveNixosHostStrict}
      exec ${pkgs.just}/bin/just host="$host" switch
    '';
    build-switch = mkAppLocal "build-switch" "Build and switch Linux host configuration" ''
      ${appRepoPreamble}
      ${resolveNixosHostStrict}
      ${pkgs.just}/bin/just host="$host" check
      exec ${pkgs.just}/bin/just host="$host" switch
    '';
    build = mkAppLocal "build" "Dry-build Linux host configuration" ''
      ${appRepoPreamble}
      ${resolveNixosHostStrict}
      exec ${pkgs.just}/bin/just host="$host" check
    '';
    install = mkAppLocal "install" "Install Linux host on Live ISO with disko+nixos-install" ''
      ${appRepoPreamble}
      ${resolveNixosHostStrict}
      exec ${pkgs.just}/bin/just host="$host" disk="''${NIXOS_DISK_DEVICE:-/dev/nvme0n1}" install
    '';
    clean = mkAppLocal "clean" "Clean old generations" ''
      ${appRepoPreamble}
      exec ${pkgs.just}/bin/just clean
    '';
  };
  evalTestChecks.${system} = mylib.specsToAttrs evalCheckSpecs mkEvalCheck;

  preCommitCheck = inputs.pre-commit-hooks.lib.${system}.run {
    src = mylib.relativeToRoot ".";
    hooks = {
      nixpkgs-fmt.enable = true;
      statix.enable = true;
      deadnix.enable = true;
    };
  };

  platformChecks.${system}.pre-commit-check = preCommitCheck;

  defaultHost = builtins.head resolvedHostNames;
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
assert lib.assertMsg
  (invalidHostNames == [ ])
  "Invalid NixOS host names under nix/hosts/nixos: ${lib.concatStringsSep ", " invalidHostNames}. Allowed pattern: ${hostNamePattern}";
assert lib.assertMsg (hostNames != [ ]) "No hosts found under nix/hosts/nixos";
{
  inherit data;
  registeredHosts = resolvedHostNames;
  inherit nixosConfigurations;
  apps = platformApps;
  checks = mylib.mergeAttrFromListWithExtra "checks" dataWithoutPaths [
    evalTestChecks
    platformChecks
  ];
  devShells = mylib.mergeAttrFromListWithExtra "devShells" dataWithoutPaths [ platformDevShells ];
  formatter = mylib.mergeAttrFromListWithExtra "formatter" dataWithoutPaths [ platformFormatter ];
}
