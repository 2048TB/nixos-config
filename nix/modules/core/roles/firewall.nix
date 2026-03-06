{ mylib, myvars, ... }:
let
  roleFlags = mylib.roleFlags myvars;
  inherit (roleFlags) enableMullvadVpn enableLibvirtd;
in
{
  networking.firewall.checkReversePath = if (enableMullvadVpn || enableLibvirtd) then "loose" else "strict";
}
