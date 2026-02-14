{ config, lib, pkgs, myvars, ... }:
let
  # GPU 驱动常量
  driverNvidia = "nvidia";
  driverAmdgpu = "amdgpu";
  driverAmdNvidiaHybrid = "amd-nvidia-hybrid";
  driverModesetting = "modesetting";
  gpuDefaultValue = "auto";

  gpuChoice = myvars.gpuMode or gpuDefaultValue;
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
  enableGpuSpecialisation = myvars.enableGpuSpecialisation or false;
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
    bluetooth = {
      enable = true;
      # 避免适配器默认掉电，减少桌面层蓝牙开关“点了无效”的概率
      powerOnBoot = true;
      # Waybar bluetooth 模块的设备电量显示依赖 BlueZ experimental
      settings = {
        General = {
          Experimental = true;
        };
      };
    };
  };

  # GPU 驱动来源：使用 flake.nix 的 myvars.gpuMode 固定配置
  services = {
    xserver.videoDrivers = videoDrivers;
    blueman.enable = true;
    power-profiles-daemon.enable = true;
    upower.enable = true;
  };

  # 兜底解除 rfkill soft block：避免蓝牙控制器在桌面会话中无法正常启用
  systemd.services.unblock-bluetooth-rfkill = {
    description = "Unblock Bluetooth rfkill state";
    wantedBy = [ "multi-user.target" ];
    after = [
      "systemd-rfkill.service"
      "bluetooth.service"
    ];
    wants = [ "bluetooth.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.util-linux}/bin/rfkill unblock bluetooth";
    };
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
