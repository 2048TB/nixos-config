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
    sbctl # Secure Boot 管理工具
    # lutris 和 proton-ge-bin 已在 modules/services-gaming.nix 中声明，无需重复
  ];

  system.stateVersion = "25.11";
}
