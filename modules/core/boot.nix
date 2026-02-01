{ lib, ... }:
{
  # Boot loader
  boot.loader = {
    systemd-boot.enable = lib.mkDefault true;
    efi.canTouchEfiVariables = true;
  };

  # Secure Boot (lanzaboote) - 默认关闭
  boot.lanzaboote = {
    enable = lib.mkDefault false;
    pkiBundle = "/etc/secureboot";
  };

  # AMD CPU
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModprobeConfig = "options kvm_amd nested=1";

  # 支持的文件系统
  boot.supportedFilesystems = [
    "ext4"
    "btrfs"
    "xfs"
    "ntfs"
    "fat"
    "vfat"
    "exfat"
  ];
}
