{ vars, ... }:
{
  services.xserver.videoDrivers = [
    "amdgpu"
    "nvidia"
  ];

  hardware.nvidia = {
    open = vars.nvidiaOpen or false;
    modesetting.enable = true;
    prime = {
      offload.enable = true;
      inherit (vars) amdgpuBusId nvidiaBusId;
    };
  };
}
