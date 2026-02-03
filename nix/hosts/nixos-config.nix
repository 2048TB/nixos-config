{ pkgs, ... }:
{
  imports = [
    ./nixos-config-hardware.nix

    # 新的模块化结构
    ../modules/system.nix
    ../modules/hardware.nix
  ];

  # 系统级最小软件
  environment.systemPackages = with pkgs; [
    sbctl # Secure Boot 管理工具
  ];

  system.stateVersion = "25.11";
}
