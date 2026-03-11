{ lib }:
let
  allowedRegistryKeys = [
    "system"
    "profiles"
    "deployEnabled"
    "deployHost"
    "deployUser"
    "deployPort"
  ];
in
rec {
  inherit allowedRegistryKeys;

  registryOwnedKeys = allowedRegistryKeys;

  mkRegistryState =
    { hostRegistry
    , hostMyvars
    }:
    let
      unknownRegistryKeys = builtins.filter
        (key: !(builtins.elem key allowedRegistryKeys))
        (builtins.attrNames hostRegistry);
      conflictingRegistryKeys = builtins.filter
        (
          key:
          builtins.hasAttr key hostMyvars
          && builtins.hasAttr key hostRegistry
          && hostMyvars.${key} != hostRegistry.${key}
        )
        registryOwnedKeys;
    in
    {
      inherit unknownRegistryKeys conflictingRegistryKeys;
      deployEnabled = hostRegistry.deployEnabled or true;
      deployHost = hostRegistry.deployHost or "";
      deployUser = hostRegistry.deployUser or "";
      deployPort = hostRegistry.deployPort or 22;
    };

  assertCommonRegistry =
    { registryPath
    , hostDir
    , hostName
    , hostRegistry
    , state
    }:
    lib.assertMsg
      (state.unknownRegistryKeys == [ ])
      "Host ${hostDir} registry entry has unsupported keys: ${lib.concatStringsSep ", " state.unknownRegistryKeys}"
    && lib.assertMsg
      (state.conflictingRegistryKeys == [ ])
      "Host ${hostDir}/vars.nix overrides registry-owned keys: ${lib.concatStringsSep ", " state.conflictingRegistryKeys}"
    && lib.assertMsg
      (builtins.isList (hostRegistry.profiles or null))
      "${registryPath}[${hostName}].profiles must be a list"
    && lib.assertMsg
      (builtins.all builtins.isString (hostRegistry.profiles or [ ]))
      "${registryPath}[${hostName}].profiles must only contain strings"
    && lib.assertMsg
      (builtins.isBool state.deployEnabled)
      "${registryPath}[${hostName}].deployEnabled must be a boolean"
    && lib.assertMsg
      (builtins.isInt state.deployPort && state.deployPort > 0)
      "${registryPath}[${hostName}].deployPort must be a positive integer"
    && lib.assertMsg
      (!state.deployEnabled || (state.deployHost != "" && state.deployUser != ""))
      "${registryPath}[${hostName}] requires deployHost and deployUser when deployEnabled = true";
}
