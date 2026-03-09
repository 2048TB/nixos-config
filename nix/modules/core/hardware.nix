{ config, lib, ... }:
let
  hostCfg = config.my.host;
  isDesktop = config.my.profiles.desktop;
  isServer = config.my.profiles.server;
  inherit (hostCfg) enableSteam;
  # GPU 驱动常量
  driverNvidia = "nvidia";
  driverAmdgpu = "amdgpu";
  driverAmdNvidiaHybrid = "amd-nvidia-hybrid";
  driverModesetting = "modesetting";
  gpuDefaultValue = "auto";

  gpuChoice = hostCfg.gpuMode or gpuDefaultValue;
  isNvidia = gpuChoice == driverNvidia;
  # 兼容历史配置/README 中的 "amd" 取值
  isAmd = gpuChoice == "amd" || gpuChoice == driverAmdgpu;
  isAmdNvidiaHybrid = gpuChoice == driverAmdNvidiaHybrid;
  useNvidia = isNvidia || isAmdNvidiaHybrid;
  # 官方默认关闭 nvidia-container-toolkit。桌面场景按需开启，避免无用 CDI 生成告警。
  inherit (hostCfg) enableNvidiaContainerToolkit;

  # 统一 NVIDIA 配置，避免专用配置与默认配置漂移
  nvidiaBase = {
    open = true;
    package = config.boot.kernelPackages.nvidiaPackages.production;
    modesetting.enable = true;
  };

  # "auto" 不建议用于实际配置，但为向后兼容保留
  # 如果是 "auto" 或其他未知值，使用安全的通用 modesetting 驱动
  videoDrivers =
    if isNvidia then [ driverNvidia ]
    else if isAmd then [ driverAmdgpu ]
    else if isAmdNvidiaHybrid then [
      driverNvidia
      driverAmdgpu
    ]
    else [ driverModesetting ]; # none、auto 或其他值都使用通用驱动

in
{
  hardware = {
    graphics = lib.mkIf isDesktop {
      enable = true;
      enable32Bit = enableSteam;
    };
    nvidia = lib.mkIf (isDesktop && useNvidia) nvidiaBase;
    nvidia-container-toolkit.enable = lib.mkIf (useNvidia && enableNvidiaContainerToolkit) true;
    bluetooth = lib.mkIf (!isServer) {
      enable = true;
      # 避免适配器默认掉电，减少桌面层蓝牙开关“点了无效”的概率
      powerOnBoot = true;
    };
  };

  # GPU 驱动来源：使用主机配置 my.host.gpuMode 固定配置
  services = {
    fwupd.enable = lib.mkIf (!isServer) true;
    xserver.videoDrivers = lib.mkIf isDesktop videoDrivers;
  };

  warnings = [ ];
}
