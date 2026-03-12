{ config
, pkgs
, lib
, mytheme
, mylib
, myvars
, osConfig ? null
, ...
}:
let
  homeDir = config.home.homeDirectory;
  localShareDir = "${homeDir}/.local/share";
  configFiles = import ../base/config-files.nix;
  hostCfg = import ../base/resolve-host.nix { inherit myvars osConfig; };
  baseNoctaliaSettings = builtins.fromJSON (builtins.readFile ../configs/noctalia/settings.json);
  baseNoctaliaWidgetsTemplate =
    let
      monitorWidgets = baseNoctaliaSettings.desktopWidgets.monitorWidgets or [ ];
    in
    if monitorWidgets == [ ] then [ ] else (builtins.head monitorWidgets).widgets;
  generatedNoctaliaSettings =
    baseNoctaliaSettings
    // {
      desktopWidgets =
        (baseNoctaliaSettings.desktopWidgets or { })
        // {
          monitorWidgets = mylib.mkNoctaliaMonitorWidgets {
            host = hostCfg;
            widgetsTemplate = baseNoctaliaWidgetsTemplate;
          };
        };
    };
  generatedNiriOutputs = mylib.mkNiriOutputs hostCfg;

  imageMimeTypes = [
    "image/jpeg"
    "image/png"
    "image/webp"
    "image/gif"
    "image/bmp"
    "image/tiff"
  ];
  imageApps = [ "org.nomacs.ImageLounge.desktop" "nomacs.desktop" ];
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
    configFile =
      sourceConfigFiles
      // forcedSourceConfigFiles
      // themedConfigFiles
      // {
        "qt6ct/colors/darker.conf".source = "${pkgs.qt6Packages.qt6ct}/share/qt6ct/colors/darker.conf";
        "niri/outputs.kdl".text = generatedNiriOutputs;
        "noctalia/settings.json".text = builtins.toJSON generatedNoctaliaSettings;
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
