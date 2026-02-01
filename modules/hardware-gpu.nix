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
  # "auto" 不应出现在实际配置中（安装脚本已修复），但为向后兼容保留
  # 如果是 "auto" 或其他未知值，使用安全的通用 modesetting 驱动
  videoDrivers =
    if isNvidia then [ "nvidia" ]
    else if isAmd then [ "amdgpu" ]
    else [ "modesetting" ];  # none、auto 或其他值都使用通用驱动

  # 是否启用 GPU specialisation（启动菜单中切换驱动）
  # 默认禁用以减少 ISO 体积和安装时间
  enableGpuSpecialisation = builtins.getEnv "ENABLE_GPU_SPECIALISATION" == "1";
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

  # GPU Specialisation：启动时在引导菜单中切换驱动
  # 默认禁用以减少 ISO 体积（~500MB）和安装时间
  # 启用方式：export ENABLE_GPU_SPECIALISATION=1
  specialisation = lib.mkIf enableGpuSpecialisation {
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
