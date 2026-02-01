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

  # 首次启动时修复 /persistent/home 权限（由于安装脚本使用硬编码 UID）
  system.activationScripts.fixPersistentHomePerms = {
    text = ''
      if [ -d /persistent/home/${myvars.username} ]; then
        chown -R ${myvars.username}:${myvars.username} /persistent/home/${myvars.username} || true
      fi
    '';
    deps = [ "users" ];
  };
}
