{ config, mylib, ... }:
let
  hostCfg = config.my.host;
  roleFlags = mylib.roleFlags hostCfg;
  inherit (roleFlags) enableVpn enableLibvirtd;
in
{
  networking.firewall.checkReversePath = if (enableVpn || enableLibvirtd) then "loose" else "strict";
}
