{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./impermanence.nix

    # 新的模块化结构
    ../../modules/core
    ../../modules/desktop
    ../../modules/hardware
    ../../modules/services
    ../../modules/storage
  ];

  # 系统级最小软件
  environment.systemPackages = with pkgs; [
    sbctl
    lutris
    proton-ge-bin
  ];

  system.stateVersion = "25.11";
}
