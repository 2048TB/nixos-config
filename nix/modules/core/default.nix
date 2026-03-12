{ config
, pkgs
, lib
, mainUser
, ...
}:
let
  hostCfg = config.my.host;
in
{
  imports = [
    ./options.nix
  ] ++ (import ./_mixins { inherit lib; });

  system.stateVersion = hostCfg.systemStateVersion;

  networking = {
    hostName = hostCfg.hostname;
    networkmanager.enable = true;
    firewall.enable = true;
  };

  time.timeZone = hostCfg.timezone;

  # 配合 tmpfs 根分区，用户数据库由配置统一管理，避免 passwd 修改丢失
  users = {
    mutableUsers = false;

    users.root = {
      hashedPasswordFile = config.sops.secrets."passwords/root".path;
    };

    groups.${mainUser} = { };

    users.${mainUser} = {
      isNormalUser = true;
      extraGroups = [
        "wheel"
        "networkmanager"
        "audio"
        "video"
        "input"
      ];
      shell = pkgs.zsh;
      hashedPasswordFile = config.sops.secrets."passwords/user".path;
    };

    defaultUserShell = pkgs.zsh;
  };
}
