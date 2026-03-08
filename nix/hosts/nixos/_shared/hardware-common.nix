{ config, lib, pkgs, ... }:
let
  hostCfg = config.my.host;
  inherit (hostCfg) cpuVendor;
in
{
  # Initrd and boot-time hardware drivers.
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

  # CPU platform and microcode.
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware = {
    enableRedistributableFirmware = lib.mkDefault true;
    cpu.amd.updateMicrocode = lib.mkDefault (
      config.hardware.enableRedistributableFirmware && cpuVendor != "intel"
    );
    cpu.intel.updateMicrocode = lib.mkDefault (
      config.hardware.enableRedistributableFirmware && cpuVendor != "amd"
    );
  };

  # 固件更新服务（BIOS/SSD/外设通过 LVFS 推送）
  services.fwupd.enable = true;

  # Host-level tools.
  environment.systemPackages = with pkgs; [
    sbctl
  ];

  # Keep stateVersion pinned for stable upgrades.
  system.stateVersion = hostCfg.systemStateVersion;
}
