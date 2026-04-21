{ lib }:
let
  inherit ((import ./host-meta.nix { })) hostMetaSchema;
  inherit (hostMetaSchema)
    allowedKinds
    allowedFormFactors
    allowedGpuVendors
    allowedLinuxDesktopProfiles
    allowedDarwinDesktopProfiles
    registryOwnedKeys
    ;
  allowedRegistryKeys = registryOwnedKeys;
in
rec {
  inherit allowedRegistryKeys allowedKinds allowedFormFactors allowedGpuVendors;

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
        allowedRegistryKeys;
    in
    {
      inherit unknownRegistryKeys conflictingRegistryKeys;
      desktopSession = hostRegistry.desktopSession or false;
      desktopProfile = hostRegistry.desktopProfile or "none";
      kind = hostRegistry.kind or "workstation";
      formFactor = hostRegistry.formFactor or "desktop";
      tags = hostRegistry.tags or [ ];
      gpuVendors = hostRegistry.gpuVendors or [ ];
      gpuMode = hostMyvars.gpuMode or null;
      roles = hostMyvars.roles or hostMetaSchema.defaultRoles;
      amdgpuBusId = hostMyvars.amdgpuBusId or null;
      nvidiaBusId = hostMyvars.nvidiaBusId or null;
      displays = hostRegistry.displays or [ ];
    };

  assertCommonRegistry =
    { registryPath
    , hostDir
    , hostName
    , state
    }:
    let
      hasVendor = vendor: builtins.elem vendor state.gpuVendors;
      gpuVendorsMatchMode =
        if state.gpuMode == null then true
        else if state.gpuMode == "none" then state.gpuVendors == [ ]
        else if state.gpuMode == "modesetting" then !(hasVendor "amd") && !(hasVendor "nvidia")
        else if state.gpuMode == "amdgpu" then (hasVendor "amd") && !(hasVendor "nvidia")
        else if state.gpuMode == "nvidia" then (hasVendor "nvidia") && !(hasVendor "amd")
        else if state.gpuMode == "amd-nvidia-hybrid" then (hasVendor "amd") && (hasVendor "nvidia")
        else false;
      primaryDisplayCount =
        builtins.length (builtins.filter (display: display.primary or false) state.displays);
    in
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
      (
        if lib.hasPrefix "nixos." hostName then
          builtins.elem state.desktopProfile allowedLinuxDesktopProfiles
        else if lib.hasPrefix "darwin." hostName then
          builtins.elem state.desktopProfile allowedDarwinDesktopProfiles
        else
          true
      )
      (
        if lib.hasPrefix "nixos." hostName then
          "${registryPath}[${hostName}].desktopProfile must be one of: ${lib.concatStringsSep ", " allowedLinuxDesktopProfiles}"
        else if lib.hasPrefix "darwin." hostName then
          "${registryPath}[${hostName}].desktopProfile must be one of: ${lib.concatStringsSep ", " allowedDarwinDesktopProfiles}"
        else
          "${registryPath}[${hostName}].desktopProfile has unsupported platform mapping"
      )
    && lib.assertMsg
      (state.desktopSession || state.desktopProfile == "none")
      "${registryPath}[${hostName}].desktopProfile must be \"none\" when desktopSession = false"
    && lib.assertMsg
      (!state.desktopSession || state.desktopProfile != "none")
      "${registryPath}[${hostName}].desktopProfile must not be \"none\" when desktopSession = true"
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
      gpuVendorsMatchMode
      "${registryPath}[${hostName}].gpuVendors (${builtins.toJSON state.gpuVendors}) is incompatible with ${hostDir}/vars.nix gpuMode='${state.gpuMode}'"
    && lib.assertMsg
      (state.gpuMode != "amd-nvidia-hybrid" || (state.amdgpuBusId != null && state.nvidiaBusId != null))
      "${hostDir}/vars.nix gpuMode='amd-nvidia-hybrid' requires both amdgpuBusId and nvidiaBusId"
    && lib.assertMsg
      (!(builtins.elem "gaming" state.roles) || state.desktopSession)
      "${hostDir}/vars.nix role 'gaming' requires ${registryPath}[${hostName}].desktopSession = true"
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
              match = display.match or null;
              primary = display.primary or false;
              scale = display.scale or null;
              width = display.width or null;
              height = display.height or null;
              refresh = display.refresh or null;
              workspaceSet = display.workspaceSet or [ ];
            in
            builtins.isString name
            && name != ""
            && (match == null || builtins.isString match)
            && builtins.isBool primary
            && (scale == null || (builtins.isFloat scale || builtins.isInt scale) && scale > 0)
            && (width == null || builtins.isInt width && width > 0)
            && (height == null || builtins.isInt height && height > 0)
            && (refresh == null || (builtins.isFloat refresh || builtins.isInt refresh) && refresh > 0)
            && builtins.isList workspaceSet
            && builtins.all (workspace: builtins.isInt workspace && workspace > 0) workspaceSet
          )
          state.displays
      )
      "${registryPath}[${hostName}].displays entries must define non-empty name, string match (when set), boolean primary (when set), positive scale, positive width/height/refresh (when set), and positive workspaceSet values"
    && lib.assertMsg
      (
        primaryDisplayCount <= 1
      )
      "${registryPath}[${hostName}].displays may define at most one primary = true entry"
    && lib.assertMsg
      (state.displays == [ ] || primaryDisplayCount == 1)
      "${registryPath}[${hostName}].displays must define exactly one primary = true entry when display metadata is declared"
  ;
}
