{ config, lib, modulesPath, pkgs, myvars, ... }:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ../modules/system.nix
    ../modules/hardware.nix
  ];

  disko.devices = {
    disk = {
      nvme0n1 = {
        type = "disk";
        device = myvars.diskDevice;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              label = "ESP";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "fmask=0022" "dmask=0022" ];
              };
            };
            NIXOS_CRYPT = {
              size = "100%";
              label = "NIXOS-CRYPT";
              content = {
                type = "luks";
                name = "crypted-nixos";
                settings = {
                  allowDiscards = true;
                };
                content = {
                  type = "btrfs";
                  extraArgs = [ "-L" "crypted-nixos" ];
                  subvolumes = {
                    "@root" = { };
                    "@nix" = {
                      mountpoint = "/nix";
                      mountOptions = [ "noatime" "compress-force=zstd:1" ];
                    };
                    "@persistent" = {
                      mountpoint = "/persistent";
                      mountOptions = [ "compress-force=zstd:1" ];
                    };
                    "@home" = {
                      mountpoint = "/home";
                      mountOptions = [ "compress=zstd" "noatime" ];
                    };
                    "@snapshots" = { };
                    "@tmp" = { };
                    "@swap" = {
                      mountpoint = "/swap";
                      mountOptions = [ "noatime" "nodatacow" "compress=no" ];
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };

  boot = {
    initrd.availableKernelModules = [
      "nvme"
      "xhci_pci"
      "ahci"
      "usbhid"
      "usb_storage"
      "sd_mod"
    ];
    initrd.kernelModules = [ ];
    extraModulePackages = [ ];
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  environment.systemPackages = with pkgs; [
    sbctl
  ];

  system.stateVersion = "25.11";
}
