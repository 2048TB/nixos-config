{ lib, mylib, inputs, system, mkApp, appRepoPreamble, ... }@args:
let
  hostsRoot = mylib.relativeToRoot "nix/hosts/darwin";
  hostNames = mylib.discoverHostNamesBy hostsRoot [
    "default.nix"
    "vars.nix"
  ];
  hostNamePattern = "^[A-Za-z0-9][A-Za-z0-9_-]*$";
  invalidHostNames = mylib.namesNotMatching hostNamePattern hostNames;

  mkHostData =
    name:
    let
      hostDir = "nix/hosts/darwin/${name}";
      hostPath = mylib.relativeToRoot "${hostDir}/default.nix";
      hostVarsPath = mylib.relativeToRoot "${hostDir}/vars.nix";
      hostChecksPath = mylib.relativeToRoot "${hostDir}/checks.nix";
      hostMyvars = import hostVarsPath;
      hostCtx = mylib.mkDarwinHost (args // {
        inherit name hostPath hostMyvars;
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
  hostnameExpr = import ./tests/hostname/expr.nix { inherit lib darwinConfigurations; };
  hostnameExpected = import ./tests/hostname/expected.nix { hostNames = resolvedHostNames; };
  homeExpr = import ./tests/home/expr.nix { inherit lib darwinConfigurations; };
  homeExpected = import ./tests/home/expected.nix { inherit mainUsers; };
  platformExpr = import ./tests/platform/expr.nix { inherit lib darwinConfigurations; };
  platformExpected = import ./tests/platform/expected.nix { inherit system; hostNames = resolvedHostNames; };
  hostEvalTests = {
    hostname = hostnameExpr == hostnameExpected;
    home = homeExpr == homeExpected;
    platform = platformExpr == platformExpected;
  };
  pkgs = import inputs.nixpkgs-darwin {
    inherit system;
    config.allowUnfree = true;
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
  resolveDarwinHostStrict = ''host="$("$repo/nix/scripts/admin/resolve-host.sh" darwin "$repo" "${builtins.head resolvedHostNames}" --strict)"'';
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
assert lib.assertMsg
  (invalidHostNames == [ ])
  "Invalid Darwin host names under nix/hosts/darwin: ${lib.concatStringsSep ", " invalidHostNames}. Allowed pattern: ${hostNamePattern}";
assert lib.assertMsg (hostNames != [ ]) "No hosts found under nix/hosts/darwin";
{
  inherit data;
  registeredHosts = resolvedHostNames;
  inherit darwinConfigurations;
  apps = platformApps;
  checks = mylib.mergeAttrFromListWithExtra "checks" dataWithoutPaths [ evalTestChecks ];
  devShells = mylib.mergeAttrFromListWithExtra "devShells" dataWithoutPaths [ ];
  formatter = mylib.mergeAttrFromListWithExtra "formatter" dataWithoutPaths [ ];
}
