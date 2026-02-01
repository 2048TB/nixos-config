{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Gaming 工具
    gamescope
    gamemode
    mangohud
    umu-launcher
    bbe

    # Wine 配置说明：
    # - stagingFull: 最完整但构建最慢（1-2 小时如果缓存过期）
    # - stable: 稳定版，通常有良好的 binary cache
    # - wayland: Wayland 优化版
    # 当前使用 stable 以确保快速安装，如需 staging 可按需切换
    wineWowPackages.stable  # 原：stagingFull（避免触发本地编译）

    winetricks
    protontricks
    protonplus
  ];
}
