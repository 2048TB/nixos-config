{ config, ... }:
let
  hostCfg = config.my.host;
  inherit (hostCfg) enableProvider appVpn enableLibvirtd;
in
{
  networking.firewall.checkReversePath = if (enableProvider appVpn || enableLibvirtd) then "loose" else "strict";
}
