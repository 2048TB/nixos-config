{ lib, vars, ... }:
{
  virtualisation.libvirtd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

  users.users.${vars.username}.extraGroups = lib.mkAfter [
    "libvirtd"
    "kvm"
  ];
}
