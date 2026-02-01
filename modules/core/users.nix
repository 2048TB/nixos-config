{ pkgs, myvars, ... }:
{
  users.mutableUsers = true;
  users.groups.${myvars.username} = {
    gid = 1000;
  };
  users.users.${myvars.username} = {
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

  # 默认 Shell
  environment.shells = with pkgs; [
    bashInteractive
    zsh
  ];
  users.defaultUserShell = pkgs.zsh;
  programs.zsh.enable = true;
}
