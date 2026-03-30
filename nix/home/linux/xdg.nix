{ config
, pkgs
, lib
, mytheme
, myvars
, osConfig ? null
, ...
}:
let
  homeDir = config.home.homeDirectory;
  localShareDir = "${homeDir}/.local/share";
  configFiles = import ../base/config-files.nix;
  hostCfg = import ../base/resolve-host.nix { inherit myvars osConfig; };
  supportsHibernate = (hostCfg.resumeOffset or null) != null;
  wlogoutLayoutLib = import ../../lib/wlogout-layout.nix { inherit lib; };
  wlogoutLayout = wlogoutLayoutLib.mkWlogoutLayout { inherit supportsHibernate; };
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
  videoMimeTypes = [
    "video/mp4"
    "video/x-matroska"
    "video/webm"
    "video/avi"
    "video/x-flv"
    "video/quicktime"
  ];
  audioMimeTypes = [
    "audio/mpeg"
    "audio/flac"
    "audio/ogg"
    "audio/wav"
    "audio/aac"
    "audio/opus"
  ];
  imageApps = [ "org.nomacs.ImageLounge.desktop" "nomacs.desktop" ];
  videoApps = [ "mpv.desktop" ];
  audioApps = [ "mpv.desktop" ];
  pdfApps = [ "org.gnome.Evince.desktop" ];
  browserApps = [ "google-chrome.desktop" ];
  portalConfig = import ../../lib/portal-config.nix;
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
in
{
  xdg = {
    dataFile."fcitx5/rime/default.custom.yaml".source = ../configs/rime/default.custom.yaml;

    configFile =
      sourceConfigFiles
      // forcedSourceConfigFiles
      // themedConfigFiles
      // {
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
        "waybar/config.jsonc".source = ../configs/waybar/config.jsonc;
        "waybar/style.css".text = mytheme.apply (builtins.readFile ../configs/waybar/style.css);
        "wlogout/layout".text = wlogoutLayout;
        "wlogout/style.css".text = mytheme.apply (builtins.readFile ../configs/wlogout/style.css);
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
        // lib.genAttrs videoMimeTypes (_: videoApps)
        // lib.genAttrs audioMimeTypes (_: audioApps)
        // {
          "inode/directory" = [ "org.gnome.Nautilus.desktop" ];
          "text/plain" = [ "org.gnome.TextEditor.desktop" ];
          "text/html" = browserApps;
          "application/pdf" = pdfApps;
          "x-scheme-handler/http" = browserApps;
          "x-scheme-handler/https" = browserApps;
        };
    };
  };
}
