{ config, ... }:
{
  services.flatpak.enable = config.my.profiles.desktop;
}
