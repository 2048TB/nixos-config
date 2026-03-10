{ lib, pkgs, ... }:
let
  brokenMt7922BluetoothPort = "/sys/devices/pci0000:00/0000:00:02.1/0000:03:00.0/0000:04:08.0/0000:06:00.0/0000:07:0c.0/0000:0e:00.0/usb1/1-0:1.0/usb1-port9";
in
{
  imports = [ ../_shared/hardware-workarounds-common.nix ];

  hardware.bluetooth.enable = lib.mkForce false;

  boot = {
    # 该主机的 MT7922 蓝牙端已确认坏掉；禁用蓝牙相关模块，避免无意义加载。
    kernelModules = lib.mkForce [ ];
    blacklistedKernelModules = [
      "btusb"
      "btmtk"
    ];

    # initrd 阶段 usb1-port9 上有异常设备反复枚举失败，会拖住 systemd-udevd stop job 约 90s。
    # 先尽早禁用坏端口，再保留较短的 udevd stop timeout 作为兜底。
    initrd.systemd.services.systemd-udevd.serviceConfig.TimeoutStopSec = "12s";

    initrd.systemd.services.disable-broken-usb1-port9 = {
      description = "Disable broken usb1-port9 early in initrd";
      wantedBy = [ "initrd.target" ];
      after = [ "systemd-udevd.service" ];
      before = [ "initrd.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart =
          let
            disableScript = pkgs.writeShellScript "disable-broken-usb1-port9" ''
              set -eu

              port="${brokenMt7922BluetoothPort}"
              tries=0

              while [ "$tries" -lt 50 ]; do
                if [ -e "$port/disable" ]; then
                  echo 1 > "$port/disable"
                  echo "Disabled ''${port##*/} in initrd."
                  exit 0
                fi

                tries=$((tries + 1))
                ${pkgs.coreutils}/bin/sleep 0.1
              done

              echo "Broken Bluetooth USB port not present in initrd, skip."
            '';
          in
          "${disableScript}";
      };
    };
  };

  systemd.services.unblock-bluetooth-rfkill.enable = lib.mkForce false;
}
