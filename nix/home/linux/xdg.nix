{ config
, pkgs
, lib
, mytheme
, mylib
, myvars
, configRepoPath
, osConfig ? null
, ...
}:
let
  homeDir = config.home.homeDirectory;
  localShareDir = "${homeDir}/.local/share";
  configFiles = import ../base/config-files.nix;
  hostCfg = import ../base/resolve-host.nix { inherit myvars osConfig; };
  generatedNiriOutputs = mylib.mkNiriOutputs hostCfg;
  mkSymlink = config.lib.file.mkOutOfStoreSymlink;

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
        "niri/outputs.kdl".text = generatedNiriOutputs;
        # 切到 repo 工作树中的可写目录，让 GUI 修改可直接持久化。
        "noctalia".source = mkSymlink "${configRepoPath}/nix/home/configs/noctalia";
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
      defaultApplications =
        lib.genAttrs imageMimeTypes (_: imageApps)
        // {
          "inode/directory" = [ "org.gnome.Nautilus.desktop" ];
          "text/plain" = [ "org.gnome.TextEditor.desktop" ];
          "text/html" = browserApps;
          "x-scheme-handler/http" = browserApps;
          "x-scheme-handler/https" = browserApps;
        };
    };
  };
}
