{ config, lib, ... }:
let
  hostCfg = config.my.host;
  inherit (hostCfg) gpuMode amdgpuBusId nvidiaBusId;
  isHybridGpu = gpuMode == "amd-nvidia-hybrid";
  hasHybridBusIds = amdgpuBusId != null && nvidiaBusId != null;
  hasExplicitPciDomain =
    busId: builtins.match "^PCI:[0-9]{1,3}@[0-9]{1,10}:[0-9]{1,2}:[0-9]$" busId != null;
in
{
  hardware.nvidia.prime = lib.mkIf (isHybridGpu && hasHybridBusIds) {
    offload = {
      enable = true;
      enableOffloadCmd = true;
    };
    inherit amdgpuBusId nvidiaBusId;
  };

  warnings = lib.optionals (isHybridGpu && !hasHybridBusIds) [
    "gpuMode=amd-nvidia-hybrid requires my.host.amdgpuBusId and my.host.nvidiaBusId (e.g. PCI:18@0:0:0 / PCI:1@0:0:0). Falling back to non-prime hybrid setup."
  ]
  ++ lib.optionals (isHybridGpu && hasHybridBusIds && !hasExplicitPciDomain amdgpuBusId) [
    "my.host.amdgpuBusId should use the explicit NixOS PRIME form PCI:<bus>@<domain>:<device>:<function> with decimal numbers (for domain 0000 use @0)."
  ]
  ++ lib.optionals (isHybridGpu && hasHybridBusIds && !hasExplicitPciDomain nvidiaBusId) [
    "my.host.nvidiaBusId should use the explicit NixOS PRIME form PCI:<bus>@<domain>:<device>:<function> with decimal numbers (for domain 0000 use @0)."
  ];
}
