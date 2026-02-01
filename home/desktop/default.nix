{ pkgs, config, ... }:
let
  mkSymlink = config.lib.file.mkOutOfStoreSymlink;
  repoRoot = "${config.home.homeDirectory}/nixos-config";
in
{
  home.packages = with pkgs; [
    # Niri 生态
    vicinae
    noctalia-shell
    swaybg

    # Wayland 基础设施
    xwayland-satellite
    wl-clipboard
    qt6Packages.qt6ct
    app2unit
  ];

  # Niri 配置文件
  xdg.configFile = {
    "niri/config.kdl".source = mkSymlink "${repoRoot}/home/niri/config.kdl";
    "niri/keybindings.kdl".source = mkSymlink "${repoRoot}/home/niri/keybindings.kdl";
    "niri/noctalia-shell.kdl".source = mkSymlink "${repoRoot}/home/niri/noctalia-shell.kdl";
    "niri/windowrules.kdl".source = mkSymlink "${repoRoot}/home/niri/windowrules.kdl";
    "niri/niri-hardware.kdl".source = mkSymlink "${repoRoot}/home/niri/niri-hardware.kdl";
    "niri/animation.kdl".source = mkSymlink "${repoRoot}/home/niri/animation.kdl";
    "niri/colors.kdl".source = mkSymlink "${repoRoot}/home/niri/colors.kdl";
    "niri/scripts".source = mkSymlink "${repoRoot}/home/niri/scripts";

    "niriswitcher/config.toml".source = mkSymlink "${repoRoot}/home/niriswitcher/config.toml";
    "niriswitcher/colors.css".source = mkSymlink "${repoRoot}/home/niriswitcher/colors.css";
    "niriswitcher/style.css".source = mkSymlink "${repoRoot}/home/niriswitcher/style.css";
  };
}
