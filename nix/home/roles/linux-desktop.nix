{
  lib,
  pkgs,
  vars,
  ...
}:
let
  desktopEnabled = pkgs.stdenv.isLinux && builtins.elem "desktop" (vars.roles or [ ]);
in
lib.mkIf desktopEnabled {
  xdg.configFile = {
    "fcitx5/profile".source = ../../../configs/fcitx5/profile;
    "fuzzel/fuzzel.ini".source = ../../../configs/fuzzel/fuzzel.ini;
    "niri".source = ../../../configs/niri;
    "noctalia".source = ../../../configs/noctalia;
  };

  systemd.user.services.noctalia-shell = {
    Unit = {
      Description = "Noctalia Shell";
      Documentation = "https://docs.noctalia.dev/docs";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };

    Service = {
      ExecStart = lib.getExe pkgs.noctalia-shell;
      Restart = "on-failure";
      Environment = [
        "QT_QPA_PLATFORM=wayland;xcb"
        "QT_QPA_PLATFORMTHEME=qt6ct"
        "QT_AUTO_SCREEN_SCALE_FACTOR=1"
      ];
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
