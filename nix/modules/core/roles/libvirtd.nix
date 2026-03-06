{ lib, mylib, myvars, mainUser, ... }:
let
  roleFlags = mylib.roleFlags myvars;
  inherit (roleFlags) enableLibvirtd;
in
{
  programs.virt-manager.enable = enableLibvirtd;

  virtualisation.libvirtd = {
    enable = enableLibvirtd;
    qemu.swtpm.enable = true;
    onBoot = "ignore"; # 不自动恢复 VM，按需 virsh start
  };

  users.users.${mainUser}.extraGroups = lib.mkAfter (
    lib.optionals enableLibvirtd [
      "libvirtd"
      "kvm"
    ]
  );
}
