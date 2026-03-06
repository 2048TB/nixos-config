{ config, lib, pkgs, myvars, ... }:
let
  # GPU 驱动常量
  driverNvidia = "nvidia";
  driverAmdgpu = "amdgpu";
  driverNvidiaPrime = "nvidia-prime";
  driverAmdNvidiaHybrid = "amd-nvidia-hybrid";
  driverModesetting = "modesetting";
  gpuDefaultValue = "auto";

  gpuChoice = myvars.gpuMode or gpuDefaultValue;
  isNvidia = gpuChoice == driverNvidia;
  isNvidiaPrime = gpuChoice == driverNvidiaPrime;
  # 兼容历史配置/README 中的 "amd" 取值
  isAmd = gpuChoice == "amd" || gpuChoice == driverAmdgpu;
  isAmdNvidiaHybrid = gpuChoice == driverAmdNvidiaHybrid;
  useNvidia = isNvidia || isNvidiaPrime || isAmdNvidiaHybrid;
  # 官方默认关闭 nvidia-container-toolkit。桌面场景按需开启，避免无用 CDI 生成告警。
  enableNvidiaContainerToolkit = myvars.enableNvidiaContainerToolkit or false;
  intelBusId = myvars.intelBusId or null;
  amdgpuBusId = myvars.amdgpuBusId or null;
  nvidiaBusId = myvars.nvidiaBusId or null;
  hasPrimeBusIds = intelBusId != null && nvidiaBusId != null;
  hasAmdNvidiaHybridBusIds = amdgpuBusId != null && nvidiaBusId != null;

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
    else if isNvidiaPrime then [ driverNvidia ]
    else if isAmd then [ driverAmdgpu ]
    else if isAmdNvidiaHybrid then [
      driverNvidia
      driverAmdgpu
    ]
    else [ driverModesetting ]; # none、auto 或其他值都使用通用驱动

  nvidiaPrimeConfig =
    (lib.optionalAttrs (isNvidiaPrime && hasPrimeBusIds) {
      prime = {
        offload = {
          enable = true;
        };
        inherit intelBusId nvidiaBusId;
      };
    })
    // (lib.optionalAttrs (isAmdNvidiaHybrid && hasAmdNvidiaHybridBusIds) {
      prime = {
        offload = {
          enable = true;
        };
        inherit amdgpuBusId nvidiaBusId;
      };
    });

  # 是否启用 GPU 专用配置（启动菜单中切换驱动）
  # 默认禁用以减少 ISO 体积和安装时间
  enableGpuSpecialisation = myvars.enableGpuSpecialisation or false;
  enableBluetoothRfkillUnblock = lib.attrByPath [ "enableBluetoothRfkillUnblock" ] false myvars;
in
{
  hardware = {
    # Wi-Fi/蓝牙/GPU 等硬件所需的可再分发固件（实体机推荐开启）
    enableRedistributableFirmware = true;

    graphics = {
      enable = true;
      enable32Bit = true;
    };
    nvidia = lib.mkIf useNvidia (nvidiaBase // nvidiaPrimeConfig);
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

  # GPU 驱动来源：使用主机 vars.nix 的 myvars.gpuMode 固定配置
  services = {
    xserver.videoDrivers = videoDrivers;
    blueman.enable = true;
    power-profiles-daemon.enable = true;
  };

  # 兜底解除 rfkill soft block：避免蓝牙控制器在启动期无法上电。
  systemd.services.unblock-bluetooth-rfkill = lib.mkIf enableBluetoothRfkillUnblock {
    description = "Unblock Bluetooth rfkill state";
    wantedBy = [ "multi-user.target" ];
    before = [ "bluetooth.service" ];
    # 仅等待 rfkill socket 就绪，避免直接拉起 systemd-rfkill.service
    # 触发 “socket service already active” 时序告警。
    after = [ "systemd-rfkill.socket" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "unblock-bluetooth-rfkill" ''
        if ${pkgs.util-linux}/bin/rfkill list bluetooth | ${pkgs.gnugrep}/bin/grep -q "Soft blocked: yes"; then
          ${pkgs.util-linux}/bin/rfkill unblock bluetooth
        fi
      '';
    };
  };

  boot = {
    # MT7922 蓝牙端走 USB 接口，部分启动时序下不会自动触发 btusb/btmtk 装载。
    # 预加载可避免 bluetooth.service 因 /sys/class/bluetooth 缺失被跳过。
    kernelModules = [ "btusb" "btmtk" ];
    kernelParams = lib.mkIf useNvidia nvidiaKernelParams;
    # Kraken 设备在无 SATA 供电或固件异常时会持续打印硬错误日志；
    # 如需该设备监控/控制能力，可删除此黑名单并先排查供电与固件。
    blacklistedKernelModules = [ "nzxt_kraken3" ];
  };

  warnings =
    lib.optionals (isNvidiaPrime && !hasPrimeBusIds) [
      "gpuMode=nvidia-prime requires myvars.intelBusId and myvars.nvidiaBusId (e.g. PCI:0:2:0 / PCI:1:0:0). Falling back to non-prime NVIDIA setup."
    ]
    ++ lib.optionals (isAmdNvidiaHybrid && !hasAmdNvidiaHybridBusIds) [
      "gpuMode=amd-nvidia-hybrid requires myvars.amdgpuBusId and myvars.nvidiaBusId (e.g. PCI:5:0:0 / PCI:1:0:0). Falling back to non-prime hybrid setup."
    ];

  # GPU 专用配置：启动时在引导菜单中切换驱动
  # 默认禁用以减少 ISO 体积（~500MB）和安装时间
  # 启用方式：在对应主机 vars.nix 中将 myvars.enableGpuSpecialisation 设为 true
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
