{ pkgs, config, myvars, ... }:
let
  mkSymlink = config.lib.file.mkOutOfStoreSymlink;
  # 支持环境变量覆盖配置路径，向后兼容 vars/default.nix
  repoRoot =
    let
      envPath = builtins.getEnv "NIXOS_CONFIG_PATH";
      homePath = "${config.home.homeDirectory}/nixos-config";
    in
      if envPath != "" then envPath
      else if builtins.pathExists homePath then homePath
      else if builtins.pathExists myvars.configRoot then myvars.configRoot
      else homePath;
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
