{ config, lib, pkgs, myvars, ... }:
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
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Host-level tools.
  environment.systemPackages = with pkgs; [
    sbctl
  ];

  # Keep stateVersion pinned for stable upgrades.
  system.stateVersion = myvars.systemStateVersion or "25.11";
}
