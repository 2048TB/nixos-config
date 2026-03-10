{ ... }:
{
  imports = [ ../_shared/hardware-workarounds-common.nix ];

  boot = {
    # initrd 阶段 usb1-port9 上有异常设备反复枚举失败，会拖住 systemd-udevd stop job 约 90s。
    # 先缩短 initrd 中 udevd 的 stop timeout，避免每次开机都被坏 USB 设备拖满默认超时。
    initrd.systemd.services.systemd-udevd.serviceConfig.TimeoutStopSec = "12s";
  };
}
