{ lib }:
let
  inherit ((import ./host-meta.nix { })) hostMetaSchema;
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
    "desktopProfile"
    "deployEnabled"
    "deployHost"
    "deployUser"
    "deployPort"
    "kind"
    "formFactor"
    "tags"
    "gpuVendors"
    "displays"
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
      desktopProfile = hostRegistry.desktopProfile or "none";
      deployEnabled = hostRegistry.deployEnabled or true;
      deployHost = hostRegistry.deployHost or "";
      deployUser = hostRegistry.deployUser or "";
      deployPort = hostRegistry.deployPort or 22;
      kind = hostRegistry.kind or "workstation";
      formFactor = hostRegistry.formFactor or "desktop";
      tags = hostRegistry.tags or [ ];
      gpuVendors = hostRegistry.gpuVendors or [ ];
      displays = hostRegistry.displays or [ ];
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
      (builtins.elem state.desktopProfile (hostMetaSchema.allowedDesktopProfiles or [ "none" ]))
      "${registryPath}[${hostName}].desktopProfile must be one of: ${lib.concatStringsSep ", " hostMetaSchema.allowedDesktopProfiles}"
    && lib.assertMsg
      (state.desktopSession || state.desktopProfile == "none")
      "${registryPath}[${hostName}].desktopProfile must be \"none\" when desktopSession = false"
    && lib.assertMsg
      (!state.desktopSession || state.desktopProfile != "none")
      "${registryPath}[${hostName}].desktopProfile must not be \"none\" when desktopSession = true"
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
      (builtins.all (tag: builtins.elem tag (hostMetaSchema.allowedHostTags or [ ])) state.tags)
      "${registryPath}[${hostName}].tags must only contain: ${lib.concatStringsSep ", " hostMetaSchema.allowedHostTags}"
    && lib.assertMsg
      (builtins.isList state.gpuVendors)
      "${registryPath}[${hostName}].gpuVendors must be a list"
    && lib.assertMsg
      (builtins.all (vendor: builtins.elem vendor allowedGpuVendors) state.gpuVendors)
      "${registryPath}[${hostName}].gpuVendors must only contain: ${lib.concatStringsSep ", " allowedGpuVendors}"
    && lib.assertMsg
      (builtins.isList state.displays)
      "${registryPath}[${hostName}].displays must be a list"
    && lib.assertMsg
      (builtins.all builtins.isAttrs state.displays)
      "${registryPath}[${hostName}].displays must only contain attribute sets"
    && lib.assertMsg
      (
        builtins.all
          (
            display:
            let
              name = display.name or "";
              scale = display.scale or null;
              workspaceSet = display.workspaceSet or [ ];
            in
            builtins.isString name
            && name != ""
            && (scale == null || (builtins.isFloat scale || builtins.isInt scale) && scale > 0)
            && builtins.isList workspaceSet
            && builtins.all (workspace: builtins.isInt workspace && workspace > 0) workspaceSet
          )
          state.displays
      )
      "${registryPath}[${hostName}].displays entries must define non-empty name, positive scale, and positive workspaceSet values"
    && lib.assertMsg
      (
        builtins.length
          (builtins.filter (display: display.primary or false) state.displays)
        <= 1
      )
      "${registryPath}[${hostName}].displays may define at most one primary = true entry"
    && lib.assertMsg
      (!state.deployEnabled || (state.deployHost != "" && state.deployUser != ""))
      "${registryPath}[${hostName}] requires deployHost and deployUser when deployEnabled = true";
}
