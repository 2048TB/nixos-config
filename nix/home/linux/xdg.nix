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
  configRepoPath = hostCfg.configRepoPath or mylib.hostMetaSchema.defaultConfigRepoPath;
  hasDesktopSession = hostCfg.desktopSession or false;
  usesNiri = (hostCfg.desktopProfile or "none") == "niri";
  generatedNiriOutputs = mylib.mkNiriOutputs hostCfg;
  mkSymlink = config.lib.file.mkOutOfStoreSymlink;
  noctaliaConfigSeedDir = "${configRepoPath}/nix/home/configs/noctalia";
  noctaliaRuntimeConfigDir = "${homeDir}/.local/state/noctalia/config";
  mkdirExe = lib.getExe' pkgs.coreutils "mkdir";
  cpExe = lib.getExe' pkgs.coreutils "cp";
  chmodExe = lib.getExe' pkgs.coreutils "chmod";

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
      configFiles.sharedSourceFiles;
  niriSourceConfigFiles =
    lib.mapAttrs (_: source: { inherit source; })
      configFiles.linuxSourceFiles;
  forcedSourceConfigFiles = lib.mapAttrs
    (_: source: {
      inherit source;
      force = true;
    })
    configFiles.linuxForcedSourceFiles;
  sharedThemedFiles = lib.genAttrs
    [
      "tmux/tmux.conf"
      "zellij/config.kdl"
    ]
    (name: configFiles.linuxThemedFiles.${name});
  desktopThemedFiles = builtins.removeAttrs configFiles.linuxThemedFiles (builtins.attrNames sharedThemedFiles);
  themedConfigFiles =
    lib.mapAttrs (_: sourcePath: { text = mytheme.apply (builtins.readFile sourcePath); })
      sharedThemedFiles;
  desktopThemedConfigFiles =
    lib.mapAttrs (_: sourcePath: { text = mytheme.apply (builtins.readFile sourcePath); })
      desktopThemedFiles;
in
{
  xdg = {
    dataFile = lib.mkIf usesNiri {
      "fcitx5/rime/default.custom.yaml".source = ../configs/rime/default.custom.yaml;
    };

    configFile =
      sourceConfigFiles
      // themedConfigFiles
      // {
        "pnpm/rc".text = ''
          global-dir=${localShareDir}/pnpm/global
          global-bin-dir=${localShareDir}/pnpm/bin
        '';
      }
      // lib.optionalAttrs usesNiri (
        niriSourceConfigFiles
        // forcedSourceConfigFiles
        // desktopThemedConfigFiles
        // {
          "qt6ct/colors/darker.conf".source = "${pkgs.qt6Packages.qt6ct}/share/qt6ct/colors/darker.conf";
          "niri/outputs.kdl".text = generatedNiriOutputs;
          # 使用用户可写的持久运行态目录；GUI 修改不再写回 tracked repo config。
          "noctalia".source = mkSymlink noctaliaRuntimeConfigDir;
        }
      );

    # Home Manager 会设置 NIX_XDG_DESKTOP_PORTAL_DIR，并优先从用户 profile 读取 .portal。
    # 需显式注入 gtk backend，否则会出现 "Requested gtk.portal is unrecognized"，
    # 进而导致 org.freedesktop.portal.Settings/FileChooser 缺失。
    portal = lib.mkIf hasDesktopSession {
      enable = true;
      xdgOpenUsePortal = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-gtk
      ];
      # portal 接口映射由 flake specialArgs 统一提供，避免 system/home 漂移。
      config = portalConfig;
    };

    userDirs = lib.mkIf hasDesktopSession {
      enable = true;
      createDirectories = true;
      extraConfig = {
        XDG_SCREENSHOTS_DIR = "$HOME/Pictures/Screenshots";
      };
    };

    mimeApps = lib.mkIf hasDesktopSession {
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

  home.activation = lib.mkIf usesNiri {
    seedNoctaliaConfig = lib.hm.dag.entryBetween [ "linkGeneration" ] [ "writeBoundary" ] ''
      seed_dir=${lib.escapeShellArg noctaliaConfigSeedDir}
      runtime_dir=${lib.escapeShellArg noctaliaRuntimeConfigDir}

      if [ ! -d "$seed_dir" ]; then
        echo "error: Noctalia config seed directory is missing: $seed_dir" >&2
        exit 1
      fi

      if [ -L "$runtime_dir" ]; then
        echo "error: Noctalia runtime config directory must not be a symlink: $runtime_dir" >&2
        exit 1
      fi

      if [ -e "$runtime_dir" ] && [ ! -d "$runtime_dir" ]; then
        echo "error: Noctalia runtime config path exists but is not a directory: $runtime_dir" >&2
        exit 1
      fi

      run ${mkdirExe} -p "$runtime_dir"
      run ${chmodExe} u+rwx "$runtime_dir"
      run ${cpExe} -R -n "$seed_dir"/. "$runtime_dir"/
    '';
  };
}
