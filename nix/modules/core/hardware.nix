{ config, lib, mylib, ... }:
let
  hostCfg = config.my.host;
  roleFlags = mylib.roleFlags hostCfg;
  isDesktop = config.my.profiles.desktop;
  isServer = config.my.profiles.server;
  inherit (roleFlags) enableSteam;
  # GPU 驱动常量
  driverNvidia = "nvidia";
  driverAmdgpu = "amdgpu";
  driverAmdNvidiaHybrid = "amd-nvidia-hybrid";
  driverModesetting = "modesetting";
  gpuDefaultValue = "auto";

  gpuChoice = hostCfg.gpuMode or gpuDefaultValue;
  isNvidia = gpuChoice == driverNvidia;
  isAmd = gpuChoice == driverAmdgpu;
  isAmdNvidiaHybrid = gpuChoice == driverAmdNvidiaHybrid;
  useNvidia = isNvidia || isAmdNvidiaHybrid;

  # 统一 NVIDIA 配置，避免专用配置与默认配置漂移
  nvidiaBase = {
    package = config.boot.kernelPackages.nvidiaPackages.production;
    modesetting.enable = true;
  } // lib.optionalAttrs (hostCfg.nvidiaOpen != null) {
    # 交由主机侧显式声明；未声明时保留 upstream 对 >=560 驱动的强制决策。
    open = hostCfg.nvidiaOpen;
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
    bluetooth = lib.mkIf (!isServer) {
      enable = true;
    };
  };

  # GPU 驱动来源：使用主机配置 my.host.gpuMode 固定配置
  services = {
    fwupd.enable = lib.mkIf (!isServer) true;
    xserver.videoDrivers = lib.mkIf isDesktop videoDrivers;
  };
}
