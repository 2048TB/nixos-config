{ lib, myvars, ... }:
{
  networking.hostName = myvars.hostname;
  networking.networkmanager.enable = true;
  networking.useDHCP = lib.mkDefault true;

  # 使 libvirt NAT 在 VPN 场景下更稳
  networking.firewall.checkReversePath = "loose";
}
