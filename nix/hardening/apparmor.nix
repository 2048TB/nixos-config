{ pkgs, ... }:
{
  # 通过 D-Bus 开启 AppArmor 介入，避免仅在内核层生效
  services.dbus.apparmor = "enabled";
  security.apparmor = {
    enable = true;

    # 强制终止未被约束但已有配置文件的进程，避免部分程序绕过策略
    killUnconfinedConfinables = true;
    packages = with pkgs; [
      apparmor-utils
      apparmor-profiles
    ];
  };
}
