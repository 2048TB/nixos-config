{ mylib, myvars, ... }:
let
  roleFlags = mylib.roleFlags myvars;
  inherit (roleFlags) enableFlatpak;
in
{
  services.flatpak.enable = enableFlatpak;
}
