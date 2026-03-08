{ config
, pkgs
, lib
, mytheme
, ...
}:
let
  homeDir = config.home.homeDirectory;
  localShareDir = "${homeDir}/.local/share";

  imageMimeTypes = [
    "image/jpeg"
    "image/png"
    "image/webp"
    "image/gif"
    "image/bmp"
    "image/tiff"
  ];
  imageApps = [ "org.nomacs.ImageLounge.desktop" "nomacs.desktop" ];
  portalConfig = import ../../modules/core/portal-config.nix;
in
{
  xdg = {
    configFile =
      {
        "qt6ct/colors/darker.conf".source = "${pkgs.qt6Packages.qt6ct}/share/qt6ct/colors/darker.conf";
        # 覆盖上游桌面自启动：避免与 provider-app-vpn-ui.service 双启动导致日志噪音与崩溃。
        "autostart/provider-app-vpn.desktop" = {
          text = ''
            [Desktop Entry]
            Type=Application
            Name=Provider app VPN
            Hidden=true
          '';
          force = true;
        };
        "niri/config.kdl".source = ../configs/niri/config.kdl;
        "niri/interaction.kdl".source = ../configs/niri/interaction.kdl;
        "niri/appearance.kdl".text = mytheme.apply (builtins.readFile ../configs/niri/appearance.kdl);

        "fcitx5/profile" = {
          source = ../configs/fcitx5/profile;
          force = true;
        };

        "fuzzel/fuzzel.ini".text = mytheme.apply (builtins.readFile ../configs/fuzzel/fuzzel.ini);
        "foot/foot.ini".text = mytheme.apply (builtins.readFile ../configs/foot/foot.ini);
        "ghostty/config".text = mytheme.apply (builtins.readFile ../configs/ghostty/config);
        "yazi/yazi.toml".source = ../configs/yazi/yazi.toml;
        "yazi/keymap.toml".source = ../configs/yazi/keymap.toml;
        "git/config".source = ../configs/git/config;
        "zellij/config.kdl".text = mytheme.apply (builtins.readFile ../configs/zellij/config.kdl);
        "tmux/tmux.conf".text = mytheme.apply (builtins.readFile ../configs/tmux/tmux.conf);
        "wallpapers" = {
          source = ../../../wallpapers;
          recursive = true;
        };

        "pnpm/rc".text = ''
          global-dir=${localShareDir}/pnpm/global
          global-bin-dir=${localShareDir}/pnpm/bin
        '';
      };

    # Home Manager 会设置 NIX_XDG_DESKTOP_PORTAL_DIR，并优先从用户 profile 读取 .portal。
    # 需显式注入 gtk backend，否则会出现 "Requested gtk.portal is unrecognized"，
    # 进而导致 org.freedesktop.portal.Settings/FileChooser 缺失。
    portal = {
      enable = true;
      xdgOpenUsePortal = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gnome
        xdg-desktop-portal-gtk
      ];
      # portal 接口映射由 flake specialArgs 统一提供，避免 system/home 漂移。
      config = portalConfig;
    };

    userDirs = {
      enable = true;
      createDirectories = true;
      extraConfig = {
        XDG_SCREENSHOTS_DIR = "$HOME/Pictures/Screenshots";
      };
    };

    mimeApps = {
      enable = true;
      # 统一图片默认打开方式
      # 使用 genAttrs 保持行为一致，减少重复
      defaultApplications = lib.genAttrs imageMimeTypes (_: imageApps) // {
        "text/plain" = [ "org.gnome.TextEditor.desktop" ];
      };
    };
  };
}
