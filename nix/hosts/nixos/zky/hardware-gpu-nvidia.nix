{ vars, ... }:
{
  hardware.nvidia = {
    open = vars.nvidiaOpen or false;
    modesetting.enable = true;
    powerManagement.enable = true;
    prime.offload.enable = false;
  };
}
