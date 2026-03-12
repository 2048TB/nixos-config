{ lib }:
let
  allowedKinds = [
    "workstation"
    "server"
    "vm"
  ];
  allowedFormFactors = [
    "desktop"
    "laptop"
    "handheld"
    "headless"
  ];
  allowedGpuVendors = [
    "amd"
    "intel"
    "nvidia"
  ];
  allowedRegistryKeys = [
    "system"
    "desktopSession"
    "deployEnabled"
    "deployHost"
    "deployUser"
    "deployPort"
    "kind"
    "formFactor"
    "tags"
    "gpuVendors"
  ];
in
rec {
  inherit allowedRegistryKeys allowedKinds allowedFormFactors allowedGpuVendors;

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
      desktopSession = hostRegistry.desktopSession or false;
      deployEnabled = hostRegistry.deployEnabled or true;
      deployHost = hostRegistry.deployHost or "";
      deployUser = hostRegistry.deployUser or "";
      deployPort = hostRegistry.deployPort or 22;
      kind = hostRegistry.kind or "workstation";
      formFactor = hostRegistry.formFactor or "desktop";
      tags = hostRegistry.tags or [ ];
      gpuVendors = hostRegistry.gpuVendors or [ ];
    };

  assertCommonRegistry =
    { registryPath
    , hostDir
    , hostName
    , state
    }:
    lib.assertMsg
      (state.unknownRegistryKeys == [ ])
      "Host ${hostDir} registry entry has unsupported keys: ${lib.concatStringsSep ", " state.unknownRegistryKeys}"
    && lib.assertMsg
      (state.conflictingRegistryKeys == [ ])
      "Host ${hostDir}/vars.nix overrides registry-owned keys: ${lib.concatStringsSep ", " state.conflictingRegistryKeys}"
    && lib.assertMsg
      (builtins.isBool state.desktopSession)
      "${registryPath}[${hostName}].desktopSession must be a boolean"
    && lib.assertMsg
      (builtins.isBool state.deployEnabled)
      "${registryPath}[${hostName}].deployEnabled must be a boolean"
    && lib.assertMsg
      (builtins.isInt state.deployPort && state.deployPort > 0)
      "${registryPath}[${hostName}].deployPort must be a positive integer"
    && lib.assertMsg
      (builtins.elem state.kind allowedKinds)
      "${registryPath}[${hostName}].kind must be one of: ${lib.concatStringsSep ", " allowedKinds}"
    && lib.assertMsg
      (builtins.elem state.formFactor allowedFormFactors)
      "${registryPath}[${hostName}].formFactor must be one of: ${lib.concatStringsSep ", " allowedFormFactors}"
    && lib.assertMsg
      (builtins.isList state.tags)
      "${registryPath}[${hostName}].tags must be a list"
    && lib.assertMsg
      (builtins.all builtins.isString state.tags)
      "${registryPath}[${hostName}].tags must only contain strings"
    && lib.assertMsg
      (builtins.isList state.gpuVendors)
      "${registryPath}[${hostName}].gpuVendors must be a list"
    && lib.assertMsg
      (builtins.all (vendor: builtins.elem vendor allowedGpuVendors) state.gpuVendors)
      "${registryPath}[${hostName}].gpuVendors must only contain: ${lib.concatStringsSep ", " allowedGpuVendors}"
    && lib.assertMsg
      (!state.deployEnabled || (state.deployHost != "" && state.deployUser != ""))
      "${registryPath}[${hostName}] requires deployHost and deployUser when deployEnabled = true";
}
