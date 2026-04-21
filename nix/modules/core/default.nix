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

  # 为硬编码 /bin/bash 的脚本提供兼容路径；用 tmpfiles 声明，避免 switch 阶段命令式改根目录。
  systemd.tmpfiles.rules = [
    "d /bin 0755 root root -"
    "L+ /bin/bash - - - - /run/current-system/sw/bin/bash"
  ];

  programs.zsh.enable = true;

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
