{ pkgs, ... }:
{
  # 游戏支持
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
    protontricks.enable = true;
  };
  programs.gamemode.enable = true;

  # Lutris / Proton GE
  environment.systemPackages = with pkgs; [
    lutris
    proton-ge-bin
  ];
}
