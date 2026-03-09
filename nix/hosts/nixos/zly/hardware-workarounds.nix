{ pkgs, ... }:
{
  boot = {
    # initrd 阶段 usb1-port9 上有异常设备反复枚举失败，会拖住 systemd-udevd stop job 约 90s。
    # 先缩短 initrd 中 udevd 的 stop timeout，避免每次开机都被坏 USB 设备拖满默认超时。
    initrd.systemd.services.systemd-udevd.serviceConfig.TimeoutStopSec = "12s";

    # MT7922 蓝牙端走 USB 接口，部分启动时序下不会自动触发 btusb/btmtk 装载。
    kernelModules = [
      "btusb"
      "btmtk"
    ];

    # Kraken 设备在无 SATA 供电或固件异常时会持续打印硬错误日志。
    blacklistedKernelModules = [ "nzxt_kraken3" ];
  };

  # 兜底解除 rfkill soft block：避免蓝牙控制器在启动期无法上电。
  systemd.services.unblock-bluetooth-rfkill = {
    description = "Unblock Bluetooth rfkill state";
    wantedBy = [ "multi-user.target" ];
    before = [ "bluetooth.service" ];
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
}
