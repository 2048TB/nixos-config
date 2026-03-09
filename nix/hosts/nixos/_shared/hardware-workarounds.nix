{ pkgs, ... }:
{
  # MT7922 蓝牙端走 USB 接口，部分启动时序下不会自动触发 btusb/btmtk 装载。
  # 这些属于机器级 workaround，不放在 shared core。
  boot.kernelModules = [
    "btusb"
    "btmtk"
  ];

  # Kraken 设备在无 SATA 供电或固件异常时会持续打印硬错误日志。
  # 保持为 host 硬件层 workaround，避免污染共享系统层。
  boot.blacklistedKernelModules = [ "nzxt_kraken3" ];

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
