{ config, ... }:
let
  hostCfg = config.my.host;
  usesNvidia = builtins.elem hostCfg.gpuMode [ "nvidia" "amd-nvidia-hybrid" ];
  usesHybridNvidia = hostCfg.gpuMode == "amd-nvidia-hybrid";
  pciBusIdPattern = "^PCI:[0-9]{1,3}@[0-9]{1,10}:[0-9]{1,2}:[0-9]$";
  hasValidPciBusId = value: value != null && builtins.match pciBusIdPattern value != null;

  userPasswordSecretFile = ../../../secrets/passwords/user-password.yaml;
  rootPasswordSecretFile = ../../../secrets/passwords/root-password.yaml;
in
{
  assertions = [
    {
      assertion = builtins.pathExists userPasswordSecretFile;
      message = "Missing secrets/passwords/user-password.yaml. Use sops workflow to create/update it.";
    }
    {
      assertion = builtins.pathExists rootPasswordSecretFile;
      message = "Missing secrets/passwords/root-password.yaml. Use sops workflow to create/update it.";
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
  ];
}
