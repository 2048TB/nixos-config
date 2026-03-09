{ config, lib, ... }:
let
  hostCfg = config.my.host;
  inherit (hostCfg) gpuMode amdgpuBusId nvidiaBusId;
  isHybridGpu = gpuMode == "amd-nvidia-hybrid";
  hasHybridBusIds = amdgpuBusId != null && nvidiaBusId != null;
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
    "gpuMode=amd-nvidia-hybrid requires my.host.amdgpuBusId and my.host.nvidiaBusId (e.g. PCI:5:0:0 / PCI:1:0:0). Falling back to non-prime hybrid setup."
  ];
}
