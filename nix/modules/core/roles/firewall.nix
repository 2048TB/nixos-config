{ mylib, myvars, ... }:
let
  roleFlags = mylib.roleFlags myvars;
  inherit (roleFlags) enableProvider appVpn enableLibvirtd;
in
{
  networking.firewall.checkReversePath = if (enableProvider appVpn || enableLibvirtd) then "loose" else "strict";
}
