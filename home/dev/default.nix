{ pkgs, ... }:
{
  # 开发工具链已提升到系统级（modules/system.nix），这里保持空以避免重复
  home.packages = with pkgs; [ ];
}
