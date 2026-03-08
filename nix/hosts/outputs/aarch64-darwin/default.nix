{ lib, mylib, inputs, system, mkApp, appRepoPreamble, ... }@args:
let
  common = import ../common.nix { inherit lib mylib; };
  hostsRoot = mylib.relativeToRoot "nix/hosts/darwin";
  registryState = common.mkRegistryState {
    kind = "darwin";
    inherit hostsRoot system;
    requiredFiles = [
      "default.nix"
      "vars.nix"
    ];
  };
  inherit (registryState) hostNames;

  mkHostData =
    name:
    let
      hostDir = "nix/hosts/darwin/${name}";
      hostPath = mylib.relativeToRoot "${hostDir}/default.nix";
      hostVarsPath = mylib.relativeToRoot "${hostDir}/vars.nix";
      hostChecksPath = mylib.relativeToRoot "${hostDir}/checks.nix";
      hostMyvars = import hostVarsPath;
      hostRegistry = mylib.hostRegistryEntry "darwin" name;
      hostCtx = mylib.mkDarwinHost (args // {
        inherit name hostPath hostMyvars hostRegistry;
      });
      hostChecks = mylib.importIfExists hostChecksPath hostCtx;
    in
    mylib.mkHostDataEntry {
      configAttrName = "darwinConfigurations";
      hostSystemAttr = "darwinSystem";
      inherit hostCtx hostChecks;
    };

  data = mylib.mapNamesToAttrs hostNames mkHostData;
  dataWithoutPaths = builtins.attrValues data;

  darwinConfigurations = mylib.mergeAttrFromList "darwinConfigurations" dataWithoutPaths;
  mainUsers = mylib.mergeAttrFromList "mainUsers" dataWithoutPaths;
  resolvedHostNames = builtins.attrNames darwinConfigurations;
  hostnameExpr = import ./hostname-expr.nix { inherit lib darwinConfigurations; };
  hostnameExpected = import ./hostname-expected.nix { hostNames = resolvedHostNames; };
  homeExpr = import ./home-expr.nix { inherit lib darwinConfigurations; };
  homeExpected = import ./home-expected.nix { inherit mainUsers; };
  platformExpr = import ./platform-expr.nix { inherit lib darwinConfigurations; };
  platformExpected = import ./platform-expected.nix { inherit system; hostNames = resolvedHostNames; };
  hostEvalTests = {
    hostname = hostnameExpr == hostnameExpected;
    home = homeExpr == homeExpected;
    platform = platformExpr == platformExpected;
  };
  pkgs = import inputs.nixpkgs-darwin {
    inherit system;
    config.allowUnfreePredicate = mylib.allowUnfreePredicate;
  };
  mkAppLocal = mkApp pkgs;
  mkEvalCheck = common.mkEvalCheck pkgs;
  evalCheckSpecs = [
    {
      name = "evaltest-darwin-hostname";
      ok = hostEvalTests.hostname;
      message = "darwin hostname eval test failed";
    }
    {
      name = "evaltest-darwin-home";
      ok = hostEvalTests.home;
      message = "darwin home eval test failed";
    }
    {
      name = "evaltest-darwin-platform";
      ok = hostEvalTests.platform;
      message = "darwin platform eval test failed";
    }
  ];
  resolveDarwinHostStrict = common.resolveHostStrictSnippet {
    kind = "darwin";
    inherit resolvedHostNames;
  };
  platformApps.${system} = {
    apply = mkAppLocal "apply" "Apply Darwin host configuration (switch)" ''
      ${appRepoPreamble}
      ${resolveDarwinHostStrict}
      exec ${pkgs.just}/bin/just darwin_host="$host" darwin-switch
    '';
    build-switch = mkAppLocal "build-switch" "Build and switch Darwin host configuration" ''
      ${appRepoPreamble}
      ${resolveDarwinHostStrict}
      ${pkgs.just}/bin/just darwin_host="$host" darwin-check
      exec ${pkgs.just}/bin/just darwin_host="$host" darwin-switch
    '';
    build = mkAppLocal "build" "Build Darwin host configuration without switching" ''
      ${appRepoPreamble}
      ${resolveDarwinHostStrict}
      exec ${pkgs.just}/bin/just darwin_host="$host" darwin-check
    '';
    clean = mkAppLocal "clean" "Clean old generations" ''
      ${appRepoPreamble}
      exec ${pkgs.just}/bin/just clean
    '';
  };
  evalTestChecks.${system} = mylib.specsToAttrs evalCheckSpecs mkEvalCheck;
in
assert common.assertRegistryState
{
  state = registryState;
  registryKey = "darwin";
  kindDisplay = "Darwin";
  hostsPath = "nix/hosts/darwin";
  inherit system;
};
{
  inherit data;
  registeredHosts = resolvedHostNames;
  inherit darwinConfigurations;
  apps = platformApps;
  checks = mylib.mergeAttrFromListWithExtra "checks" dataWithoutPaths [ evalTestChecks ];
  devShells = mylib.mergeAttrFromListWithExtra "devShells" dataWithoutPaths [ ];
  formatter = mylib.mergeAttrFromListWithExtra "formatter" dataWithoutPaths [ ];
}
