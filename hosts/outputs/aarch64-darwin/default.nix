{ lib, mylib, inputs, system, mkApp, appRepoPreamble, ... }@args:
let
  hostsRoot = mylib.relativeToRoot "hosts/darwin";
  hostNames = mylib.discoverHostNamesBy hostsRoot [
    "default.nix"
    "vars.nix"
  ];

  mkHostData =
    name:
    let
      hostDir = "hosts/darwin/${name}";
      hostPath = mylib.relativeToRoot "${hostDir}/default.nix";
      hostVarsPath = mylib.relativeToRoot "${hostDir}/vars.nix";
      hostChecksPath = mylib.relativeToRoot "${hostDir}/checks.nix";
      hostMyvars = import hostVarsPath;
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

  darwinConfigurations =
    mylib.mergeRecursiveAttrsList (map (it: it.darwinConfigurations or { }) dataWithoutPaths);
  mainUsers = mylib.mergeRecursiveAttrsList (map (it: it.mainUsers or { }) dataWithoutPaths);
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
  resolveDarwinHostStrict = ''host="$("$repo/scripts/resolve-host.sh" darwin "$repo" "zly-mac" --strict)"'';
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
  evalTestChecks.${system} = {
    evaltest-darwin-hostname = pkgs.runCommand "evaltest-darwin-hostname" { } ''
      if [ "${if hostEvalTests.hostname then "1" else "0"}" != "1" ]; then
        echo "darwin hostname eval test failed" >&2
        exit 1
      fi
      touch "$out"
    '';
    evaltest-darwin-home = pkgs.runCommand "evaltest-darwin-home" { } ''
      if [ "${if hostEvalTests.home then "1" else "0"}" != "1" ]; then
        echo "darwin home eval test failed" >&2
        exit 1
      fi
      touch "$out"
    '';
    evaltest-darwin-platform = pkgs.runCommand "evaltest-darwin-platform" { } ''
      if [ "${if hostEvalTests.platform then "1" else "0"}" != "1" ]; then
        echo "darwin platform eval test failed" >&2
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
  inherit darwinConfigurations;
  apps = platformApps;
  checks =
    mylib.mergeRecursiveAttrsList (
      (map (it: it.checks or { }) dataWithoutPaths)
      ++ [ evalTestChecks ]
    );
  devShells = mylib.mergeRecursiveAttrsList (map (it: it.devShells or { }) dataWithoutPaths);
  formatter = mylib.mergeRecursiveAttrsList (map (it: it.formatter or { }) dataWithoutPaths);
}
