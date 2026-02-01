{ pkgs, mainUser, ... }:
{
  users.mutableUsers = true;
  users.groups.${mainUser} = {
    gid = 1000;
  };
  users.users.${mainUser} = {
    uid = 1000;
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "audio"
      "video"
      "input"
      "libvirtd"
      "kvm"
    ];
    shell = pkgs.zsh;
    hashedPasswordFile = "/persistent/etc/user-password";
  };
}
