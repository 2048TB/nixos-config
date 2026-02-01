{ config, lib, ... }:
{
  # 模板文件：请在安装后用 `nixos-generate-config` 生成并替换 UUID。
  # 布局：LUKS + Btrfs 子卷 + swapfile + tmpfs 根分区（impermanence 风格）。

  boot.initrd.luks.devices."crypted-nixos" = {
    device = "/dev/disk/by-uuid/CHANGE-ME-LUKS-UUID";
    allowDiscards = true;
    bypassWorkqueues = true;
  };

  boot.supportedFilesystems = [
    "ext4"
    "btrfs"
    "xfs"
    "ntfs"
    "fat"
    "vfat"
    "exfat"
  ];

  # 根分区：tmpfs
  fileSystems."/" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "relatime"
      "mode=755"
    ];
  };

  # Btrfs 子卷挂载
  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/CHANGE-ME-BTRFS-UUID";
    fsType = "btrfs";
    options = [
      "subvol=@nix"
      "noatime"
      "compress-force=zstd:1"
    ];
  };

  fileSystems."/persistent" = {
    device = "/dev/disk/by-uuid/CHANGE-ME-BTRFS-UUID";
    fsType = "btrfs";
    options = [
      "subvol=@persistent"
      "compress-force=zstd:1"
    ];
    neededForBoot = true;
  };

  fileSystems."/snapshots" = {
    device = "/dev/disk/by-uuid/CHANGE-ME-BTRFS-UUID";
    fsType = "btrfs";
    options = [
      "subvol=@snapshots"
      "compress-force=zstd:1"
    ];
  };

  fileSystems."/tmp" = {
    device = "/dev/disk/by-uuid/CHANGE-ME-BTRFS-UUID";
    fsType = "btrfs";
    options = [
      "subvol=@tmp"
      "compress-force=zstd:1"
    ];
  };

  # swap 子卷先只读，再 bind swapfile
  fileSystems."/swap" = {
    device = "/dev/disk/by-uuid/CHANGE-ME-BTRFS-UUID";
    fsType = "btrfs";
    options = [
      "subvol=@swap"
      "ro"
    ];
  };

  fileSystems."/swap/swapfile" = {
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

  # EFI 分区
  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/CHANGE-ME-ESP-UUID";
    fsType = "vfat";
  };

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
