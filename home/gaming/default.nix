{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Gaming 工具
    gamescope
    gamemode
    mangohud
    umu-launcher
    bbe
    wineWowPackages.stagingFull
    winetricks
    protontricks
    protonplus
  ];
}
