{ lib, mylib, inputs, system, mkApp, appRepoPreamble, ... }@args:
let
  common = import ../common.nix { inherit lib mylib; };
  hostsRoot = mylib.relativeToRoot "nix/hosts/nixos";
  registryState = common.mkRegistryState {
    kind = "nixos";
    inherit hostsRoot system;
    requiredFiles = [
      "hardware.nix"
      "disko.nix"
      "vars.nix"
    ];
  };
  inherit (registryState) hostNames;

  mkHostData =
    name:
    let
      hostDir = "nix/hosts/nixos/${name}";
      hostDefaultPath = mylib.relativeToRoot "${hostDir}/default.nix";
      hostVarsPath = mylib.relativeToRoot "${hostDir}/vars.nix";
      hostChecksPath = mylib.relativeToRoot "${hostDir}/checks.nix";
      sharedChecksPath = mylib.relativeToRoot "nix/hosts/nixos/_shared/checks.nix";
      generatedDesktopChecksPath = mylib.relativeToRoot "nix/hosts/nixos/_shared/generated-desktop-checks.nix";
      hostMyvars = import hostVarsPath;
      hostRegistry = mylib.hostRegistryEntry "nixos" name;
      hostCtx = mylib.mkNixosHost (args // {
        inherit name hostMyvars hostRegistry;
        hostPath = if builtins.pathExists hostDefaultPath then hostDefaultPath else null;
      });
      hostCheckArgs = hostCtx // { inherit (args) lib mylib; };
      hostChecks =
        (import sharedChecksPath hostCheckArgs)
        // (import generatedDesktopChecksPath hostCheckArgs)
        // (mylib.importIfExists hostChecksPath hostCheckArgs);
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

  hostnameExpr = common.mapHostValuesByPath [ "config" "networking" "hostName" ] nixosConfigurations;
  hostnameExpected = common.mkExpectedHostNames resolvedHostNames;
  homeExpr = common.mapHomeDirectories nixosConfigurations;
  homeExpected = common.mkExpectedHomeDirectories "/home" mainUsers;
  kernelExpr = common.mapHostValuesByPath [ "config" "boot" "kernelPackages" "kernel" "system" ] nixosConfigurations;
  kernelExpected = common.mkExpectedAttrSet resolvedHostNames system;
  platformExpr = common.mapHostValuesByPath [ "pkgs" "stdenv" "hostPlatform" "system" ] nixosConfigurations;
  platformExpected = common.mkExpectedAttrSet resolvedHostNames system;
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
  mkEvalCheck = common.mkEvalCheck pkgs;
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
  platformApps.${system} = {
    install = mkAppLocal "install" "Install Linux host on Live ISO with disko+nixos-install" ''
      ${appRepoPreamble}
      host="''${NIXOS_HOST:-}"
      if [ -z "$host" ]; then
        echo "error: NIXOS_HOST is required for nix run .#install" >&2
        echo "hint: NIXOS_HOST=${builtins.head resolvedHostNames} NIXOS_DISK_DEVICE=/dev/nvme0n1 nix run .#install" >&2
        exit 2
      fi
      exec ${pkgs.just}/bin/just host="$host" disk="''${NIXOS_DISK_DEVICE:-/dev/nvme0n1}" install
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
assert common.assertRegistryState
{
  state = registryState;
  registryKey = "nixos";
  kindDisplay = "NixOS";
  hostsPath = "nix/hosts/nixos";
  inherit system;
};
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
