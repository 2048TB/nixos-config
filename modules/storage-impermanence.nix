{ config, lib, ... }:
let
  btrfsDevice = config.fileSystems."/nix".device;
 in
{
  fileSystems."/" = lib.mkForce {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "relatime"
      "mode=755"
    ];
  };

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
