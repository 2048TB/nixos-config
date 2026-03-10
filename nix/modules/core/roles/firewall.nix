{ config, mylib, ... }:
let
  hostCfg = config.my.host;
  roleFlags = mylib.roleFlags hostCfg;
  inherit (roleFlags) enableProvider appVpn enableLibvirtd;
in
{
  networking.firewall.checkReversePath = if (enableProvider appVpn || enableLibvirtd) then "loose" else "strict";
}
