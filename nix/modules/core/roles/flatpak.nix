{ config, ... }:
{
  services.flatpak.enable = config.my.capabilities.hasDesktopSession;
}
