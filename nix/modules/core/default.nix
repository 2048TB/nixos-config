{ config
, pkgs
, myvars
, mainUser
, ...
}:
let
  defaultUid = 1000;
  defaultGid = 1000;
in
{
  imports = [
    ./nix-settings.nix
    ./assertions.nix
    ./roles/firewall.nix
    ./roles/steam.nix
    ./roles/provider-app.nix
    ./roles/flatpak.nix
    ./roles/libvirtd.nix
    ./roles/docker.nix
    ./boot.nix
    ./storage.nix
    ./security.nix
    ./desktop.nix
    ./services.nix
    ./secrets.nix
  ];

  networking = {
    hostName = myvars.hostname;
    networkmanager.enable = true;
    firewall.enable = true;
  };

  time.timeZone = myvars.timezone;

  # 配合 tmpfs 根分区，用户数据库由配置统一管理，避免 passwd 修改丢失
  users = {
    mutableUsers = false;

    users.root = {
      hashedPasswordFile = config.sops.secrets."passwords/root".path;
    };

    groups.${mainUser} = {
      gid = defaultGid;
    };

    users.${mainUser} = {
      uid = defaultUid;
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
