{ ... }:
{
  # Noctalia 依赖项（WiFi/蓝牙/电源/电池）
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;
}
