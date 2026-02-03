{ config, lib, preservation, mainUser, ... }:
let
  # 从 /nix 文件系统获取 Btrfs 设备路径
  # 如果 hardware-configuration.nix 尚未生成，使用占位符
  btrfsDevice =
    if config.fileSystems ? "/nix" && config.fileSystems."/nix" ? device
    then config.fileSystems."/nix".device
    else "/dev/mapper/crypted-nixos";  # 默认值，安装后会被覆盖
in
{
  imports = [ preservation.nixosModules.default ];

  preservation.enable = true;
  # preservation 需要 initrd systemd
  boot.initrd.systemd.enable = true;

  preservation.preserveAt."/persistent" = {
    directories = [
      "/etc/NetworkManager/system-connections"
      "/etc/ssh"
      "/etc/nix"
      "/etc/secureboot"

      "/var/log"
      "/var/lib/nixos"
      "/var/lib/systemd"
      "/var/lib/NetworkManager"
      "/var/lib/bluetooth"
    ];
    files = [
      {
        file = "/etc/machine-id";
        inInitrd = true;
      }
    ];

    users.${mainUser} = {
      directories = [
        "Downloads"
        "Documents"
        "Pictures"
        "Videos"
        "Music"
        "nixos-config"
        ".config"
        ".local/share"
        ".local/state"
        ".cache"
      ];
    };
  };

  fileSystems."/" = lib.mkForce {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "relatime"
      "mode=755"
    ];
  };

  # swap 子卷：禁用 COW 和压缩以支持 swapfile
  fileSystems."/swap" = lib.mkForce {
    device = btrfsDevice;
    fsType = "btrfs";
    options = [
      "subvol=@swap"
      "noatime"
      "nodatacow"
      "compress=no"
    ];
  };

  fileSystems."/swap/swapfile" = lib.mkForce {
    depends = [ "/swap" ];
    device = "/swap/swapfile";
    fsType = "none";
    options = [
      "bind"
      "rw"
    ];
  };

  swapDevices = [
    { device = "/swap/swapfile"; }
  ];

  fileSystems."/persistent".neededForBoot = lib.mkDefault true;
}
