{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix

    # 新的模块化结构
    ../../modules/system.nix
    ../../modules/desktop.nix
    ../../modules/hardware.nix
    ../../modules/services.nix
    ../../modules/storage.nix
  ];

  # 系统级最小软件
  environment.systemPackages = with pkgs; [
    sbctl
    lutris
    proton-ge-bin
  ];

  system.stateVersion = "25.11";
}
