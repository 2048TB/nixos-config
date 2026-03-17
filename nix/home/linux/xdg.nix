{ config
, pkgs
, lib
, mytheme
, myvars
, osConfig ? null
, userProfileBin
, ...
}:
let
  homeDir = config.home.homeDirectory;
  localShareDir = "${homeDir}/.local/share";
  configFiles = import ../base/config-files.nix;
  hostCfg = import ../base/resolve-host.nix { inherit myvars osConfig; };
  isLaptop = (hostCfg.formFactor or "desktop") == "laptop";
  supportsHibernate = (hostCfg.resumeOffset or null) != null;
  imageMimeTypes = [
    "image/jpeg"
    "image/png"
    "image/webp"
    "image/gif"
    "image/bmp"
    "image/tiff"
  ];
  imageApps = [ "org.nomacs.ImageLounge.desktop" "nomacs.desktop" ];
  browserApps = [ "google-chrome.desktop" ];
  portalConfig = import ../../lib/portal-config.nix;
  wlogoutLayoutLib = import ../../lib/wlogout-layout.nix { inherit lib; };
  sourceConfigFiles =
    lib.mapAttrs (_: source: { inherit source; })
      (configFiles.sharedSourceFiles // configFiles.linuxSourceFiles);
  forcedSourceConfigFiles = lib.mapAttrs
    (_: source: {
      inherit source;
      force = true;
    })
    configFiles.linuxForcedSourceFiles;
  themedConfigFiles =
    lib.mapAttrs (_: sourcePath: { text = mytheme.apply (builtins.readFile sourcePath); })
      configFiles.linuxThemedFiles;
  waybarDeviceModules =
    lib.concatStringsSep "\n" (lib.optionals isLaptop [
      "    \"backlight\","
      "    \"battery\","
    ]);
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
  wlogoutLayout = wlogoutLayoutLib.mkWlogoutLayout { inherit supportsHibernate; };
in
{
  xdg = {
    configFile =
      sourceConfigFiles
      // forcedSourceConfigFiles
      // themedConfigFiles
      // {
        "qt6ct/colors/darker.conf".source = "${pkgs.qt6Packages.qt6ct}/share/qt6ct/colors/darker.conf";
        "waybar/config".text = waybarConfig;
        "waybar/style.css".text = waybarStyle;
        "waybar/icons" = {
          source = ../configs/waybar/icons;
          recursive = true;
          force = true;
        };
        "wlogout/layout".text = wlogoutLayout;
        "wlogout/style.css".text = mytheme.apply (builtins.readFile ../configs/wlogout/style.css);
        "wallpapers" = {
          source = ../../../wallpapers;
          recursive = true;
        };
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
        xdg-desktop-portal-wlr
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
      defaultApplications =
        lib.genAttrs imageMimeTypes (_: imageApps)
        // {
          "text/plain" = [ "org.gnome.TextEditor.desktop" ];
          "text/html" = browserApps;
          "x-scheme-handler/http" = browserApps;
          "x-scheme-handler/https" = browserApps;
        };
    };
  };
}
