{ mylib, config, ... }:
let
  hostCfg = config.my.host;
  roleFlags = mylib.roleFlags hostCfg;
  inherit (roleFlags) enableFlatpak;
in
{
  services.flatpak.enable = enableFlatpak;
}
