{ config, lib, myvars, ... }:
let
  # GPU 驱动常量
  driverNvidia = "nvidia";
  driverAmdgpu = "amdgpu";
  driverAmdNvidiaHybrid = "amd-nvidia-hybrid";
  driverModesetting = "modesetting";
  gpuDefaultValue = "auto";

  envGpu = builtins.getEnv "NIXOS_GPU";

  # GPU 配置文件路径（按优先级排序）
  gpuConfigPaths = [
    ../vars/detected-gpu.txt
    ../hosts/${myvars.hostname}-gpu-choice.txt
    ../hosts/${myvars.hostname}/gpu-choice.txt
    ../hosts/nixos-config/gpu-choice.txt
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
  # 兼容安装脚本/README 的 "amd" 取值
  isAmd = gpuChoice == "amd" || gpuChoice == driverAmdgpu;
  isAmdNvidiaHybrid = gpuChoice == driverAmdNvidiaHybrid;
  useNvidia = isNvidia || isAmdNvidiaHybrid;

  # 统一 NVIDIA 配置，避免专用配置与默认配置漂移
  nvidiaKernelParams = [ "nvidia-drm.fbdev=1" ];
  nvidiaBase = {
    open = true;
    package = config.boot.kernelPackages.nvidiaPackages.production;
    modesetting.enable = true;
    powerManagement.enable = true;
  };

  # "auto" 不应出现在实际配置中（安装脚本已修复），但为向后兼容保留
  # 如果是 "auto" 或其他未知值，使用安全的通用 modesetting 驱动
  videoDrivers =
    if isNvidia then [ driverNvidia ]
    else if isAmd then [ driverAmdgpu ]
    else if isAmdNvidiaHybrid then [
      driverNvidia
      driverAmdgpu
    ]
    else [ driverModesetting ]; # none、auto 或其他值都使用通用驱动

  # 是否启用 GPU 专用配置（启动菜单中切换驱动）
  # 默认禁用以减少 ISO 体积和安装时间
  enableGpuSpecialisation = builtins.getEnv "ENABLE_GPU_SPECIALISATION" == "1";
in
{
  # 图形基础设置（Wayland + Xwayland）
  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    nvidia = lib.mkIf useNvidia nvidiaBase;
    nvidia-container-toolkit.enable = lib.mkIf useNvidia true;
    bluetooth.enable = true;
  };

  # 安装时通过 NIXOS_GPU 或 nix/vars/detected-gpu.txt 选择默认驱动
  services = {
    xserver.videoDrivers = videoDrivers;
    blueman.enable = true;
    power-profiles-daemon.enable = true;
    upower.enable = true;
  };

  boot.kernelParams = lib.mkIf useNvidia nvidiaKernelParams;

  # GPU 专用配置：启动时在引导菜单中切换驱动
  # 默认禁用以减少 ISO 体积（~500MB）和安装时间
  # 启用方式：export ENABLE_GPU_SPECIALISATION=1
  specialisation = lib.mkIf enableGpuSpecialisation {
    gpu-amd.configuration = {
      services.xserver.videoDrivers = [ driverAmdgpu ];
    };

    gpu-nvidia.configuration = {
      services.xserver.videoDrivers = [ driverNvidia ];
      boot.kernelParams = nvidiaKernelParams;
      hardware = {
        nvidia = nvidiaBase;
        nvidia-container-toolkit.enable = true;
        graphics.enable32Bit = true;
      };
    };

    gpu-none.configuration = {
      services.xserver.videoDrivers = [ driverModesetting ];
    };
  };

}
