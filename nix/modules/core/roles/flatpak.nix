{ config, ... }:
let
  hostCfg = config.my.host;
  inherit (hostCfg) enableFlatpak;
in
{
  services.flatpak.enable = enableFlatpak;
}
