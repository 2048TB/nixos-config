# ⚠️ 此文件将在安装时由 nixos-generate-config 自动生成
# ⚠️ 请勿手动编辑此文件，运行 scripts/auto-install.sh 会覆盖它
#
# 预期布局：LUKS + Btrfs 子卷 + swapfile + tmpfs 根分区
#
# 如果你是手动安装（不使用 auto-install.sh），请运行：
#   sudo nixos-generate-config --root /mnt
#   # 然后将生成的 /mnt/etc/nixos/hardware-configuration.nix 复制到这里
#
# 参考模板（实际 UUID 会被自动替换）：
#
# { config, lib, pkgs, modulesPath, ... }:
# {
#   imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
#
#   boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usb_storage" "sd_mod" ];
#   boot.initrd.kernelModules = [ ];
#   boot.kernelModules = [ "kvm-amd" ];  # 或 kvm-intel
#   boot.extraModulePackages = [ ];
#
#   boot.initrd.luks.devices."crypted-nixos" = {
#     device = "/dev/disk/by-uuid/<ACTUAL-LUKS-UUID>";
#     allowDiscards = true;
#     bypassWorkqueues = true;
#   };
#
#   fileSystems."/" = {
#     device = "tmpfs";
#     fsType = "tmpfs";
#     options = [ "relatime" "mode=755" ];
#   };
#
#   fileSystems."/nix" = {
#     device = "/dev/disk/by-uuid/<ACTUAL-BTRFS-UUID>";
#     fsType = "btrfs";
#     options = [ "subvol=@nix" "noatime" "compress-force=zstd:1" ];
#   };
#
#   fileSystems."/persistent" = {
#     device = "/dev/disk/by-uuid/<ACTUAL-BTRFS-UUID>";
#     fsType = "btrfs";
#     options = [ "subvol=@persistent" "compress-force=zstd:1" ];
#     neededForBoot = true;
#   };
#
#   fileSystems."/snapshots" = {
#     device = "/dev/disk/by-uuid/<ACTUAL-BTRFS-UUID>";
#     fsType = "btrfs";
#     options = [ "subvol=@snapshots" "compress-force=zstd:1" ];
#   };
#
#   fileSystems."/tmp" = {
#     device = "/dev/disk/by-uuid/<ACTUAL-BTRFS-UUID>";
#     fsType = "btrfs";
#     options = [ "subvol=@tmp" "compress-force=zstd:1" ];
#   };
#
#   # swap 子卷由 system.nix 管理，这里只定义基本挂载
#   # system.nix 会使用 mkForce 覆盖
#
#   fileSystems."/boot" = {
#     device = "/dev/disk/by-uuid/<ACTUAL-ESP-UUID>";
#     fsType = "vfat";
#   };
#
#   swapDevices = [ ];
#
#   networking.useDHCP = lib.mkDefault true;
#   nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
#   hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
# }

# 临时占位符，防止 flake check 失败
# 注意：此配置仅用于开发/检查，实际安装会完全替换此文件
{ lib, ... }: {
  boot = {
    initrd.availableKernelModules = lib.mkDefault [
      "nvme"
      "xhci_pci"
      "ahci"
      "usb_storage"
      "sd_mod"
    ];
    initrd.luks.devices."crypted-nixos" = lib.mkDefault {
      device = "/dev/disk/by-partlabel/NIXOS-CRYPT";
      allowDiscards = true;
      bypassWorkqueues = true;
    };
    loader.systemd-boot.enable = lib.mkDefault true;
    loader.efi.canTouchEfiVariables = lib.mkDefault true;
  };

  # 占位符文件系统（实际安装后会被 nixos-generate-config 覆盖）
  fileSystems = {
    "/" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [ "relatime" "mode=755" ];
    };

    "/nix" = {
      device = "/dev/mapper/crypted-nixos";
      fsType = "btrfs";
      options = [ "subvol=@nix" "noatime" "compress-force=zstd:1" ];
    };

    "/persistent" = {
      device = "/dev/mapper/crypted-nixos";
      fsType = "btrfs";
      options = [ "subvol=@persistent" "compress-force=zstd:1" ];
      neededForBoot = true;
    };

    "/home" = {
      device = "/dev/mapper/crypted-nixos";
      fsType = "btrfs";
      options = [ "subvol=@home" "compress=zstd" "noatime" ];
      neededForBoot = true; # greetd 依赖 /home/.wayland-session
    };

    "/boot" = {
      device = "/dev/disk/by-label/ESP";
      fsType = "vfat";
    };
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
