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
  # 兼容历史配置/README 中的 "amd" 取值
  isAmd = gpuChoice == "amd" || gpuChoice == driverAmdgpu;
  isAmdNvidiaHybrid = gpuChoice == driverAmdNvidiaHybrid;
  useNvidia = isNvidia || isAmdNvidiaHybrid;
  # 官方默认关闭 nvidia-container-toolkit。桌面场景按需开启，避免无用 CDI 生成告警。
  enableNvidiaContainerToolkit = myvars.enableNvidiaContainerToolkit or false;

  # 统一 NVIDIA 配置，避免专用配置与默认配置漂移
  nvidiaKernelParams = [ "nvidia-drm.fbdev=1" ];
  nvidiaBase = {
    open = true;
    package = config.boot.kernelPackages.nvidiaPackages.production;
    modesetting.enable = true;
    powerManagement.enable = true;
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
    nvidia-container-toolkit.enable = lib.mkIf (useNvidia && enableNvidiaContainerToolkit) true;
    bluetooth = {
      enable = true;
      # 官方选项：通过 bluetoothd --noplugin 关闭有问题的插件。
      disabledPlugins = [ "bap" ];
      # 避免适配器默认掉电，减少桌面层蓝牙开关“点了无效”的概率
      powerOnBoot = true;
      # 保留 experimental 以兼容电量与 LE 特性。
      settings = {
        General = {
          Experimental = true;
        };
      };
    };
  };

  # GPU 驱动来源：使用 hosts/vars/default.nix 的 myvars.gpuMode 固定配置
  services = {
    xserver.videoDrivers = videoDrivers;
    blueman.enable = true;
    power-profiles-daemon.enable = true;
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

  boot = {
    kernelParams = lib.mkIf useNvidia nvidiaKernelParams;
    # Kraken 设备在无 SATA 供电或固件异常时会持续打印硬错误日志；
    # 如需该设备监控/控制能力，可删除此黑名单并先排查供电与固件。
    blacklistedKernelModules = [ "nzxt_kraken3" ];
  };

  # GPU 专用配置：启动时在引导菜单中切换驱动
  # 默认禁用以减少 ISO 体积（~500MB）和安装时间
  # 启用方式：在 hosts/vars/default.nix 中将 myvars.enableGpuSpecialisation 设为 true
  specialisation = lib.mkIf enableGpuSpecialisation {
    gpu-amd.configuration = {
      services.xserver.videoDrivers = [ driverAmdgpu ];
    };

    gpu-nvidia.configuration = {
      services.xserver.videoDrivers = [ driverNvidia ];
      boot.kernelParams = nvidiaKernelParams;
      hardware = {
        nvidia = nvidiaBase;
        nvidia-container-toolkit.enable = enableNvidiaContainerToolkit;
        graphics.enable32Bit = true;
      };
    };

    gpu-none.configuration = {
      services.xserver.videoDrivers = [ driverModesetting ];
    };
  };

}
