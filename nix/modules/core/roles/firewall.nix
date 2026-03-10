{ config, mylib, ... }:
let
  hostCfg = config.my.host;
  roleFlags = mylib.roleFlags hostCfg;
  inherit (roleFlags) enableMullvadVpn enableLibvirtd;
in
{
  networking.firewall.checkReversePath = if (enableMullvadVpn || enableLibvirtd) then "loose" else "strict";
}
