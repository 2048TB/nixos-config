{
  lib,
  host,
  vars,
  platform,
  registryHost,
  ...
}:
let
  getAttrOrNull = name: set: if builtins.hasAttr name set then builtins.getAttr name set else null;
  supportedFormFactors = [
    "desktop"
    "laptop"
  ];
  supportedLanguageTools = [
    "go"
    "node"
    "python"
    "rust"
  ];
  supportedCpuVendors = [
    "amd"
    "apple"
    "intel"
  ];
  supportedGpuModes = [
    "amd"
    "amd-nvidia-hybrid"
    "nvidia"
  ];
  supportedDockerModes = [ "rootless" ];
  overlapFields = [
    "system"
    "formFactor"
    "languageTools"
    "roles"
  ];
  registryMismatchFields = builtins.filter (
    name: (getAttrOrNull name vars) != (getAttrOrNull name registryHost)
  ) overlapFields;
  varsHostName = vars.hostName or host;
  languageTools = vars.languageTools or [ ];
  roles = vars.roles or [ ];
  hasSwapConfig = (vars ? diskDevice) || (vars ? swapSizeGb) || (vars ? resumeOffset);
  gpuMode = vars.gpuMode or null;
  dockerMode = vars.dockerMode or null;
in
{
  assertions = [
    {
      assertion = varsHostName == host;
      message = "Host `${host}` has vars.hostName `${varsHostName}`, which must match the registry key.";
    }
    {
      assertion = vars ? username;
      message = "Host `${host}` is missing required field `username` in vars.nix.";
    }
    {
      assertion = vars ? system;
      message = "Host `${host}` is missing required field `system` in vars.nix.";
    }
    {
      assertion = vars ? timezone;
      message = "Host `${host}` is missing required field `timezone` in vars.nix.";
    }
    {
      assertion = vars ? formFactor;
      message = "Host `${host}` is missing required field `formFactor` in vars.nix.";
    }
    {
      assertion = vars ? languageTools;
      message = "Host `${host}` is missing required field `languageTools` in vars.nix.";
    }
    {
      assertion = vars ? roles;
      message = "Host `${host}` is missing required field `roles` in vars.nix.";
    }
    {
      assertion = builtins.elem (vars.formFactor or "") supportedFormFactors;
      message =
        "Host `${host}` has unsupported formFactor `${
          toString (vars.formFactor or null)
        }`. Supported values: "
        + lib.concatStringsSep ", " supportedFormFactors;
    }
    {
      assertion = builtins.all (tool: builtins.elem tool supportedLanguageTools) languageTools;
      message =
        "Host `${host}` has unsupported languageTools in vars.nix. Supported values: "
        + lib.concatStringsSep ", " supportedLanguageTools;
    }
    {
      assertion = registryHost.platform == platform;
      message = "Host `${host}` is registered as platform `${registryHost.platform}`, but is being evaluated as `${platform}`.";
    }
    {
      assertion = registryMismatchFields == [ ];
      message =
        "Host `${host}` has registry drift for fields: "
        + lib.concatStringsSep ", " registryMismatchFields
        + ". Keep nix/registry/systems.toml and vars.nix aligned.";
    }
    {
      assertion = platform != "nixos" || vars ? systemStateVersion;
      message = "NixOS host `${host}` is missing required field `systemStateVersion`.";
    }
    {
      assertion = vars ? homeStateVersion;
      message = "Host `${host}` is missing required field `homeStateVersion`.";
    }
    {
      assertion =
        platform != "nixos"
        || !hasSwapConfig
        || ((vars ? diskDevice) && (vars ? swapSizeGb) && (vars ? resumeOffset));
      message = "NixOS host `${host}` must define `diskDevice`, `swapSizeGb`, and `resumeOffset` together for the current Btrfs swapfile layout.";
    }
    {
      assertion = !(vars ? cpuVendor) || builtins.elem vars.cpuVendor supportedCpuVendors;
      message =
        "Host `${host}` has unsupported cpuVendor `${
          toString (vars.cpuVendor or null)
        }`. Supported values: "
        + lib.concatStringsSep ", " supportedCpuVendors;
    }
    {
      assertion = !(vars ? gpuMode) || builtins.elem gpuMode supportedGpuModes;
      message =
        "Host `${host}` has unsupported gpuMode `${toString gpuMode}`. Supported values: "
        + lib.concatStringsSep ", " supportedGpuModes;
    }
    {
      assertion = gpuMode != "nvidia" || vars ? nvidiaOpen;
      message = "Host `${host}` uses gpuMode = \"nvidia\" and must define `nvidiaOpen`.";
    }
    {
      assertion =
        gpuMode != "amd-nvidia-hybrid"
        || ((vars ? amdgpuBusId) && (vars ? nvidiaBusId) && (vars ? nvidiaOpen));
      message = "Host `${host}` uses gpuMode = \"amd-nvidia-hybrid\" and must define `amdgpuBusId`, `nvidiaBusId`, and `nvidiaOpen`.";
    }
    {
      assertion = dockerMode == null || builtins.elem dockerMode supportedDockerModes;
      message =
        "Host `${host}` has unsupported dockerMode `${toString dockerMode}`. Supported values: "
        + lib.concatStringsSep ", " supportedDockerModes;
    }
    {
      assertion = dockerMode == null || builtins.elem "container" roles;
      message = "Host `${host}` defines dockerMode but does not enable the `container` role.";
    }
    {
      assertion = !(builtins.elem "container" roles) || dockerMode != null;
      message = "Host `${host}` enables the `container` role but does not define `dockerMode`.";
    }
  ];
}
