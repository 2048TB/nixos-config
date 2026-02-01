{ config, lib, myvars, ... }:
let
  envGpu = builtins.getEnv "NIXOS_GPU";
  gpuChoiceFile =
    let
      newPath = ../vars/detected-gpu.txt;
      legacyPath = ../hosts/${myvars.hostname}/gpu-choice.txt;
      path = if builtins.pathExists newPath then newPath else legacyPath;
      raw = if builtins.pathExists path then builtins.readFile path else "auto";
    in
      lib.strings.removeSuffix "\n" (lib.strings.removeSuffix "\r" raw);
  gpuChoice = if envGpu != "" then envGpu else gpuChoiceFile;
  isNvidia = gpuChoice == "nvidia";
  isAmd = gpuChoice == "amd";
  isNone = gpuChoice == "none";
  videoDrivers =
    if isAmd then [ "amdgpu" ]
    else if isNone then [ "modesetting" ]
    else if isNvidia then [ "nvidia" ]
    else [ "amdgpu" "modesetting" ];
in
{
  # Base graphics setup (Wayland + Xwayland)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # 安装时通过 NIXOS_GPU 或 vars/detected-gpu.txt 选择默认驱动
  services.xserver.videoDrivers = videoDrivers;

  boot.kernelParams = lib.mkIf isNvidia [ "nvidia-drm.fbdev=1" ];
  hardware.nvidia = lib.mkIf isNvidia {
    open = true;
    package = config.boot.kernelPackages.nvidiaPackages.production;
    modesetting.enable = true;
    powerManagement.enable = true;
  };
  hardware.nvidia-container-toolkit.enable = lib.mkIf isNvidia true;

  # 三种 GPU 变体：启动时在引导菜单中选择
  specialisation = {
    gpu-amd.configuration = {
      services.xserver.videoDrivers = [ "amdgpu" ];
    };

    gpu-nvidia.configuration = {
      services.xserver.videoDrivers = [ "nvidia" ];
      boot.kernelParams = [ "nvidia-drm.fbdev=1" ];
      hardware.nvidia = {
        open = true;
        package = config.boot.kernelPackages.nvidiaPackages.production;
        modesetting.enable = true;
        powerManagement.enable = true;
      };
      hardware.nvidia-container-toolkit.enable = true;
      hardware.graphics.enable32Bit = true;
    };

    gpu-none.configuration = {
      services.xserver.videoDrivers = [ "modesetting" ];
    };
  };
}
