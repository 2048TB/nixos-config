{ myvars }:
let
  hostRoles = myvars.roles or [ "desktop" ];
  hasRole = role: builtins.elem role hostRoles;
  dockerMode = myvars.dockerMode or "rootless";
in
{
  inherit hostRoles hasRole dockerMode;
  enableMullvadVpn = myvars.enableMullvadVpn or (hasRole "vpn");
  enableLibvirtd = myvars.enableLibvirtd or (hasRole "virt");
  enableDocker = myvars.enableDocker or (hasRole "container");
  enableFlatpak = myvars.enableFlatpak or (hasRole "desktop");
  enableSteam = myvars.enableSteam or (hasRole "gaming");
  useRootfulDocker = dockerMode == "rootful";
  useRootlessDocker = dockerMode == "rootless";
}
