{ pkgs, ... }:
{
  # 游戏支持
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
    protontricks.enable = true;
  };
  programs.gamemode.enable = true;

  # Lutris
  environment.systemPackages = with pkgs; [
    lutris
  ];

  # Proton-GE 配置：通过 Steam extraCompatPackages 安装
  # 注意：不能放在 environment.systemPackages（会导致 buildEnv 错误）
  programs.steam.extraCompatPackages = with pkgs; [
    proton-ge-bin
  ];
}
