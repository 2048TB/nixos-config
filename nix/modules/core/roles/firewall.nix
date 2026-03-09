{ config, ... }:
let
  hostCfg = config.my.host;
  inherit (hostCfg) enableMullvadVpn enableLibvirtd;
in
{
  networking.firewall.checkReversePath = if (enableMullvadVpn || enableLibvirtd) then "loose" else "strict";
}
