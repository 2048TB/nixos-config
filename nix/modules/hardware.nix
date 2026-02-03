{ config, lib, myvars, ... }:
let
  # GPU 驱动常量
  driverNvidia = "nvidia";
  driverAmdgpu = "amdgpu";
  driverModesetting = "modesetting";
  gpuDefaultValue = "auto";

  envGpu = builtins.getEnv "NIXOS_GPU";

  # GPU 配置文件路径（按优先级排序）
  gpuConfigPaths = [
    ../vars/detected-gpu.txt
    ../hosts/${myvars.hostname}-gpu-choice.txt
    ../hosts/nixos-config-gpu-choice.txt
    ../hosts/${myvars.hostname}/gpu-choice.txt
    ../hosts/nixos-cconfig/gpu-choice.txt
  ];

  # 查找第一个存在的 GPU 配置文件
  findFirstExistingPath = paths:
    if paths == [ ] then null
    else if builtins.pathExists (builtins.head paths) then builtins.head paths
    else findFirstExistingPath (builtins.tail paths);

  gpuConfigPath = findFirstExistingPath gpuConfigPaths;

  gpuChoiceFile =
    let
      raw =
        if gpuConfigPath != null
        then builtins.readFile gpuConfigPath
        else gpuDefaultValue;
    in
    lib.strings.removeSuffix "\n" (lib.strings.removeSuffix "\r" raw);
  gpuChoice = if envGpu != "" then envGpu else gpuChoiceFile;
  isNvidia = gpuChoice == driverNvidia;
  isAmd = gpuChoice == driverAmdgpu;
  isNone = gpuChoice == "none";

  # "auto" 不应出现在实际配置中（安装脚本已修复），但为向后兼容保留
  # 如果是 "auto" 或其他未知值，使用安全的通用 modesetting 驱动
  videoDrivers =
    if isNvidia then [ driverNvidia ]
    else if isAmd then [ driverAmdgpu ]
    else [ driverModesetting ]; # none、auto 或其他值都使用通用驱动

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

  # 安装时通过 NIXOS_GPU 或 nix/vars/detected-gpu.txt 选择默认驱动
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
      services.xserver.videoDrivers = [ driverAmdgpu ];
    };

    gpu-nvidia.configuration = {
      services.xserver.videoDrivers = [ driverNvidia ];
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
      services.xserver.videoDrivers = [ driverModesetting ];
    };
  };

  # Noctalia 依赖项（WiFi/蓝牙/电源/电池）
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;
}
