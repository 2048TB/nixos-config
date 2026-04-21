{ config, ... }:
let
  hostCfg = config.my.host;
  hostLabel = "host ${hostCfg.hostname}";
  hostRoles = hostCfg.roles or [ ];
  usesNvidia = builtins.elem hostCfg.gpuMode [ "nvidia" "amd-nvidia-hybrid" ];
  usesHybridNvidia = hostCfg.gpuMode == "amd-nvidia-hybrid";
  pciBusIdPattern = "^PCI:[0-9]{1,3}@[0-9]{1,10}:[0-9]{1,2}:[0-9]$";
  hasValidPciBusId = value: value != null && builtins.match pciBusIdPattern value != null;
  hasVendor = vendor: builtins.elem vendor hostCfg.gpuVendors;
  gpuVendorsMatchMode =
    if hostCfg.gpuMode == "none" then hostCfg.gpuVendors == [ ]
    else if hostCfg.gpuMode == "modesetting" then !(hasVendor "amd") && !(hasVendor "nvidia")
    else if hostCfg.gpuMode == "amdgpu" then (hasVendor "amd") && !(hasVendor "nvidia")
    else if hostCfg.gpuMode == "nvidia" then (hasVendor "nvidia") && !(hasVendor "amd")
    else if hostCfg.gpuMode == "amd-nvidia-hybrid" then (hasVendor "amd") && (hasVendor "nvidia")
    else false;
  primaryDisplayCount = builtins.length (builtins.filter (display: display.primary or false) hostCfg.displays);

  repoRoot = ../../..;
  secretPath = rel: repoRoot + "/${rel}";
  firstExistingSecretFile = preferred: legacy:
    let
      preferredPath = secretPath preferred;
      legacyPath = secretPath legacy;
    in
    if builtins.pathExists preferredPath then preferredPath else legacyPath;
  userPasswordSecretFile = firstExistingSecretFile
    "secrets/common/passwords/user-password.yaml"
    "secrets/passwords/user-password.yaml";
  rootPasswordSecretFile = firstExistingSecretFile
    "secrets/common/passwords/root-password.yaml"
    "secrets/passwords/root-password.yaml";
in
{
  assertions = [
    {
      assertion = builtins.pathExists userPasswordSecretFile;
      message = "Missing secrets/common/passwords/user-password.yaml (legacy fallback: secrets/passwords/user-password.yaml). Use sops workflow to create/update it.";
    }
    {
      assertion = builtins.pathExists rootPasswordSecretFile;
      message = "Missing secrets/common/passwords/root-password.yaml (legacy fallback: secrets/passwords/root-password.yaml). Use sops workflow to create/update it.";
    }
    {
      assertion = gpuVendorsMatchMode;
      message = "${hostLabel}: my.host.gpuVendors (${builtins.toJSON hostCfg.gpuVendors}) is incompatible with my.host.gpuMode='${hostCfg.gpuMode}'.";
    }
    {
      assertion = hostCfg.desktopSession || hostCfg.desktopProfile == "none";
      message = "${hostLabel}: my.host.desktopProfile must be 'none' when my.host.desktopSession=false.";
    }
    {
      assertion = (!hostCfg.desktopSession) || hostCfg.desktopProfile != "none";
      message = "${hostLabel}: my.host.desktopProfile must not be 'none' when my.host.desktopSession=true.";
    }
    {
      assertion = hostCfg.displays == [ ] || primaryDisplayCount == 1;
      message = "${hostLabel}: my.host.displays must contain exactly one primary=true entry when display metadata is declared.";
    }
    {
      assertion = !(builtins.elem "gaming" hostRoles) || hostCfg.desktopSession;
      message = "${hostLabel}: role 'gaming' requires my.host.desktopSession=true because Steam/gamescope are desktop services.";
    }
    {
      assertion = (!usesNvidia) || hostCfg.nvidiaOpen != null;
      message = "When my.host.gpuMode uses NVIDIA, set my.host.nvidiaOpen explicitly (true for Turing+ GPUs that should use the open kernel module, false for hosts that require the proprietary-only kernel modules).";
    }
    {
      assertion = (!usesHybridNvidia) || (hostCfg.amdgpuBusId != null && hostCfg.nvidiaBusId != null);
      message = "When my.host.gpuMode=amd-nvidia-hybrid, set both my.host.amdgpuBusId and my.host.nvidiaBusId.";
    }
    {
      assertion = (!usesHybridNvidia) || hasValidPciBusId hostCfg.amdgpuBusId;
      message = "my.host.amdgpuBusId must use the explicit NixOS PRIME form PCI:<bus>@<domain>:<device>:<function> with decimal numbers.";
    }
    {
      assertion = (!usesHybridNvidia) || hasValidPciBusId hostCfg.nvidiaBusId;
      message = "my.host.nvidiaBusId must use the explicit NixOS PRIME form PCI:<bus>@<domain>:<device>:<function> with decimal numbers.";
    }
    {
      assertion = usesHybridNvidia || (hostCfg.nvidiaBusId == null && hostCfg.amdgpuBusId == null);
      message = "my.host.nvidiaBusId and my.host.amdgpuBusId are only used when gpuMode is amd-nvidia-hybrid; current gpuMode is '${hostCfg.gpuMode}'.";
    }
    {
      assertion = usesNvidia || hostCfg.nvidiaOpen == null;
      message = "my.host.nvidiaOpen is only used when gpuMode is nvidia or amd-nvidia-hybrid; current gpuMode is '${hostCfg.gpuMode}'.";
    }
  ];
}
