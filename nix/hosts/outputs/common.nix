{ lib, mylib }:
{
  mkRegistryState =
    { kind
    , hostsRoot
    , requiredFiles
    , system
    }:
    let
      discoveredHostNames = mylib.discoverHostNamesBy hostsRoot requiredFiles;
      hostNames = mylib.registryHostNamesByKind kind;
      missingInRegistry =
        builtins.filter (name: !(builtins.elem name hostNames)) discoveredHostNames;
      missingOnDisk =
        builtins.filter (name: !(builtins.elem name discoveredHostNames)) hostNames;
      wrongSystemHosts =
        builtins.filter
          (name: ((mylib.hostRegistryEntry kind name).system or "") != system)
          hostNames;
      hostNamePattern = "^[A-Za-z0-9][A-Za-z0-9_-]*$";
      invalidHostNames = mylib.namesNotMatching hostNamePattern hostNames;
    in
    {
      inherit
        discoveredHostNames
        hostNames
        missingInRegistry
        missingOnDisk
        wrongSystemHosts
        hostNamePattern
        invalidHostNames
        ;
    };

  assertRegistryState =
    { state
    , registryKey
    , kindDisplay
    , hostsPath
    , system
    }:
    lib.assertMsg
      (state.invalidHostNames == [ ])
      "Invalid ${kindDisplay} host names under ${hostsPath}: ${lib.concatStringsSep ", " state.invalidHostNames}. Allowed pattern: ${state.hostNamePattern}"
    && lib.assertMsg
      (state.missingInRegistry == [ ])
      "Host directories exist but are not registered in nix/hosts/registry/systems.toml[${registryKey}]: ${lib.concatStringsSep ", " state.missingInRegistry}"
    && lib.assertMsg
      (state.missingOnDisk == [ ])
      "Hosts are registered in nix/hosts/registry/systems.toml[${registryKey}] but required files are missing: ${lib.concatStringsSep ", " state.missingOnDisk}"
    && lib.assertMsg
      (state.wrongSystemHosts == [ ])
      "Hosts registered under ${registryKey} with mismatched system (${system} expected): ${lib.concatStringsSep ", " state.wrongSystemHosts}"
    && lib.assertMsg (state.hostNames != [ ]) "No hosts found under ${hostsPath}";

  mkEvalCheck =
    pkgs:
    { name, ok, message }:
    pkgs.runCommand name { } ''
      if [ "${if ok then "1" else "0"}" != "1" ]; then
        echo "${message}" >&2
        exit 1
      fi
      touch "$out"
    '';

  mapHostValuesByPath =
    path: configurations:
    lib.mapAttrs (_: cfg: lib.attrByPath path null cfg) configurations;

  mapHomeDirectories =
    configurations:
    lib.mapAttrs
      (
        hostName:
        cfg:
        let
          users = builtins.attrNames (cfg.config.home-manager.users or { });
          user = builtins.head users;
        in
        assert lib.assertMsg (users != [ ]) "No Home Manager users found for host ${hostName}"
          && lib.assertMsg
          (builtins.length users == 1)
          "Expected exactly one Home Manager user for host ${hostName}, got ${toString (builtins.length users)}";
        cfg.config.home-manager.users.${user}.home.homeDirectory
      )
      configurations;

  mkExpectedAttrSet =
    hostNames: value:
    builtins.listToAttrs (
      map
        (name: {
          inherit name;
          inherit value;
        })
        hostNames
    );

  mkExpectedHostNames =
    hostNames:
    builtins.listToAttrs (
      map
        (name: {
          inherit name;
          value = name;
        })
        hostNames
    );

  mkExpectedHomeDirectories =
    homeRoot: mainUsers:
    builtins.mapAttrs (_host: user: "${homeRoot}/${user}") mainUsers;

  resolveHostStrictSnippet =
    { kind, resolvedHostNames }:
    ''host="$("$repo/nix/scripts/admin/resolve-host.sh" ${kind} "$repo" "${builtins.head resolvedHostNames}" --strict)"'';
}
