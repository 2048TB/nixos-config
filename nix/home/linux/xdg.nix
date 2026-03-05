{ config
, pkgs
, lib
, myvars
, mytheme
, userProfileBin
, ...
}:
let
  homeDir = config.home.homeDirectory;
  localShareDir = "${homeDir}/.local/share";
  enableWaybarBacklight = myvars.enableWaybarBacklight or false;
  enableWaybarBattery = myvars.enableWaybarBattery or false;
  waybarDeviceModules =
    lib.concatStringsSep "\n" (
      (lib.optionals enableWaybarBacklight [ "    \"backlight\"," ])
      ++ (lib.optionals enableWaybarBattery [ "    \"battery\"," ])
    );

  waybarConfig =
    builtins.replaceStrings
      [
        "@USER_BIN@"
        "@SYSTEM_BIN@"
        "@WAYBAR_DEVICE_MODULES@"
      ]
      [
        userProfileBin
        "/run/current-system/sw/bin"
        waybarDeviceModules
      ]
      (builtins.readFile ../configs/waybar/config.jsonc);
  waybarStyle =
    builtins.replaceStrings
      [
        "@WAYBAR_PACMAN_ICON@"
      ]
      [
        "${../configs/waybar/icons/pacman.svg}"
      ]
      (mytheme.apply (builtins.readFile ../configs/waybar/style.css));

  wlogoutIconNames = [
    "lock"
    "logout"
    "suspend"
    "hibernate"
    "reboot"
    "shutdown"
  ];
  wlogoutIconFiles =
    lib.genAttrs
      (map (name: "wlogout/icons/${name}.png") wlogoutIconNames)
      (path: { source = "${pkgs.wlogout}/share/${path}"; });

  imageMimeTypes = [
    "image/jpeg"
    "image/png"
    "image/webp"
    "image/gif"
    "image/bmp"
    "image/tiff"
  ];
  imageApps = [ "org.nomacs.ImageLounge.desktop" "nomacs.desktop" ];
  portalConfig = import ../../portal-config.nix;
in
{
  xdg = {
    configFile =
      {
        "qt6ct/colors/darker.conf".source = "${pkgs.qt6Packages.qt6ct}/share/qt6ct/colors/darker.conf";
        # 覆盖上游桌面自启动：避免与 mullvad-vpn-ui.service 双启动导致日志噪音与崩溃。
        "autostart/mullvad-vpn.desktop" = {
          text = ''
            [Desktop Entry]
            Type=Application
            Name=Mullvad VPN
            Hidden=true
          '';
          force = true;
        };
        # 覆盖系统 autostart：维持功能不变，仅过滤启动期已知噪音日志。
        "autostart/nm-applet.desktop" = {
          text = ''
            [Desktop Entry]
            Type=Application
            Name=NetworkManager Applet
            Exec=${userProfileBin}/nm-applet-quiet
            Terminal=false
            NoDisplay=true
            NotShowIn=KDE;GNOME;COSMIC;
            X-GNOME-UsesNotifications=true
          '';
          force = true;
        };
        "autostart/pasystray.desktop" = {
          text = ''
            [Desktop Entry]
            Type=Application
            Name=PulseAudio System Tray
            Exec=${userProfileBin}/pasystray-quiet
            Icon=pasystray
            StartupNotify=true
            Terminal=false
          '';
          force = true;
        };
        "waybar/config".text = waybarConfig;
        "waybar/style.css".text = waybarStyle;
        "waybar/icons" = {
          source = ../configs/waybar/icons;
          recursive = true;
          force = true;
        };
        "niri/config.kdl".source = ../configs/niri/config.kdl;
        "niri/interaction.kdl".source = ../configs/niri/interaction.kdl;
        "niri/appearance.kdl".text = mytheme.apply (builtins.readFile ../configs/niri/appearance.kdl);
        "wlogout/layout".source = ../configs/wlogout/layout;
        "wlogout/style.css".text = mytheme.apply (builtins.readFile ../configs/wlogout/style.css);

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
          source = ../configs/wallpapers;
          recursive = true;
        };

        "pnpm/rc".text = ''
          global-dir=${localShareDir}/pnpm/global
          global-bin-dir=${localShareDir}/pnpm/bin
        '';
      }
      // wlogoutIconFiles;

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
