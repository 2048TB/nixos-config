{ config
, pkgs
, lib
, mainUser
, myvars
, ...
}:
let
  homeDir = config.home.homeDirectory;
  userProfileBin = "/etc/profiles/per-user/${mainUser}/bin";
  roleFlags = import ../../modules/system/role-flags.nix { inherit myvars; };
  inherit (roleFlags) enableProvider appVpn;

  # ===== 日志过滤启动器工厂 =====
  mkLogFilteredLauncher =
    name: executable: filters:
    let
      mkSedDeleteExpr = pattern:
        let
          # sed 地址默认使用 `/.../` 分隔，先转义 `/` 避免表达式截断。
          escapedPattern = lib.replaceStrings [ "/" ] [ "\\/" ] pattern;
        in
        "/${escapedPattern}/d";
      sedDeleteArgs =
        lib.concatMapStringsSep " \\\n"
          (pattern: "          -e ${lib.escapeShellArg (mkSedDeleteExpr pattern)}")
          filters;
    in
    pkgs.writeShellScriptBin name ''
            set -euo pipefail
            sedBin="${pkgs.gnused}/bin/sed"

            set +e
            ${executable} "$@" 2>&1 \
              | "$sedBin" -u -E \
      ${sedDeleteArgs}
              >&2
            status="''${PIPESTATUS[0]}"
            set -e
            exit "$status"
    '';

  # ===== Quiet launcher 定义 =====
  waybarQuiet = mkLogFilteredLauncher "waybar-quiet" "${pkgs.waybar}/bin/waybar" [
    "Item .*No icon name or pixmap given\\."
    "Status Notifier Item with bus name '.*' and object path '/org/ayatana/NotificationItem/udiskie' is already registered"
    "Unable to replace properties on 0: Error getting properties for ID"
  ];
  nmAppletQuiet = mkLogFilteredLauncher "nm-applet-quiet" "${pkgs.networkmanagerapplet}/bin/nm-applet" [
    "gtk_widget_get_scale_factor: assertion 'GTK_IS_WIDGET \\(widget\\)' failed"
  ];
  pasystrayQuiet = mkLogFilteredLauncher "pasystray-quiet" "${pkgs.pasystray}/bin/pasystray" [
    "Error initializing Avahi: Daemon not running"
    "gtk_radio_menu_item_get_group: assertion 'GTK_IS_RADIO_MENU_ITEM \\(radio_menu_item\\)' failed"
  ];
  swayncQuiet = mkLogFilteredLauncher "swaync-quiet" "${pkgs.swaynotificationcenter}/bin/swaync" [
    "gtk_native_get_surface: assertion 'GTK_IS_NATIVE \\(self\\)' failed"
  ];
  udiskieQuiet = mkLogFilteredLauncher "udiskie-quiet" "${pkgs.udiskie}/bin/udiskie" [
    "gtk_widget_get_scale_factor: assertion 'GTK_IS_WIDGET \\(widget\\)' failed"
  ];
  provider-appVpnQuiet = mkLogFilteredLauncher "provider-app-vpn-quiet" "${pkgs.provider-app-vpn}/bin/provider-app-vpn" [
    "Gtk: gtk_widget_get_scale_factor: assertion 'GTK_IS_WIDGET \\(widget\\)' failed"
  ];

  # ===== Waybar 启动器（Fix 2: 修复重复启动 bug） =====
  waybarLauncher = pkgs.writeShellScript "waybar-launcher" ''
    set -euo pipefail
    runtimeDir="''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}"
    waybarBin="${lib.getExe waybarQuiet}"
    sleepBin="${pkgs.coreutils}/bin/sleep"
    seqBin="${pkgs.coreutils}/bin/seq"

    launch_waybar() {
      "$waybarBin"
    }

    launch_if_wayland_ready() {
      if [ -n "''${WAYLAND_DISPLAY:-}" ] && [ -S "$runtimeDir/$WAYLAND_DISPLAY" ]; then
        launch_waybar
        return 0
      fi

      for socket in "$runtimeDir"/wayland-*; do
        [ -S "$socket" ] || continue
        export WAYLAND_DISPLAY="''${socket##*/}"
        launch_waybar
        return 0
      done

      return 1
    }

    for _ in $("$seqBin" 1 100); do
      launch_if_wayland_ready || true
      "$sleepBin" 0.1
    done

    exit 1
  '';

  # ===== Swaybg 启动器 =====
  swaybgLauncher = pkgs.writeShellScript "swaybg-launcher" ''
    set -euo pipefail
    wallpaperDir="${homeDir}/.config/wallpapers"
    wallpaper="$wallpaperDir/1.png"

    randomWallpaper="$(
      ${pkgs.findutils}/bin/find "$wallpaperDir" -maxdepth 1 \
        \( -type f -o -type l \) \
        \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.gif' \) \
      | ${pkgs.coreutils}/bin/shuf \
      | ${pkgs.coreutils}/bin/head -n 1
    )"
    if [ -n "$randomWallpaper" ]; then
      wallpaper="$randomWallpaper"
    fi

    exec ${pkgs.swaybg}/bin/swaybg -i "$wallpaper" -m fill
  '';

  # ===== SwayNC 配置 =====
  swayncSettings = {
    "$schema" = "/etc/xdg/swaync/configSchema.json";
    positionX = "right";
    positionY = "top";
    layer = "overlay";
    "control-center-layer" = "top";
    "layer-shell" = true;
    "control-center-margin-top" = 10;
    "control-center-margin-bottom" = 10;
    "control-center-margin-right" = 10;
    "control-center-margin-left" = 10;
    "notification-2fa-action" = true;
    "notification-inline-replies" = false;
    "notification-body-image-height" = 100;
    "notification-body-image-width" = 200;
    timeout = 10;
    "timeout-low" = 5;
    "timeout-critical" = 0;
    "fit-to-screen" = true;
    "relative-timestamps" = true;
    "control-center-width" = 500;
    "control-center-height" = 900;
    "notification-window-width" = 450;
    "keyboard-shortcuts" = true;
    "notification-grouping" = true;
    "image-visibility" = "when-available";
    "transition-time" = 200;
    "hide-on-clear" = false;
    "hide-on-action" = true;
    "text-empty" = "No Notifications";
    widgets = [
      "title"
      "dnd"
      "notifications"
      # 暂时移除 mpris：swaync 0.12.3 在当前会话下启动期会触发 GTK assertion。
    ];
    "widget-config" = {
      title = {
        text = "Notification Center";
        "clear-all-button" = true;
        "button-text" = "Clear";
      };
      dnd = {
        text = "Do Not Disturb";
      };
      label = {
        "max-lines" = 1;
        text = "Notification Center";
      };
      mpris = {
        "image-size" = 80;
        "image-radius" = 8;
        # 在空元数据播放器场景下，自动隐藏并忽略聚合器，避免断言噪音
        autohide = true;
        blacklist = [
          "org.mpris.MediaPlayer2.playerctld"
          "playerctld"
        ];
      };
      notifications = { };
    };
  };
  swayncStyle = ''
    * {
      font-family: "Maple Mono NF CN", "Sarasa UI SC", "JetBrainsMono Nerd Font", sans-serif;
      font-size: 13px;
    }

    .control-center {
      background: #1e1e2e;
      border: 1px solid rgba(255, 255, 255, 0.12);
      border-radius: 14px;
    }

    .control-center .widget-title,
    .control-center .widget-dnd,
    .control-center .widget-mpris {
      background: rgba(255, 255, 255, 0.03);
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: 10px;
      margin: 8px 10px 0 10px;
      padding: 8px 10px;
    }

    .control-center .widget-title > button {
      background: #89b4fa;
      color: #1e1e2e;
      border-radius: 8px;
      border: none;
      padding: 4px 10px;
    }

    .notification-row:focus,
    .notification-row:hover {
      background: transparent;
    }

    .notification {
      background: #1e1e2e;
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: 12px;
      margin: 6px 10px;
      padding: 0;
    }

    .notification-content {
      padding: 8px 10px;
    }

    .notification-default-action:hover,
    .notification-action:hover {
      background: rgba(137, 180, 250, 0.18);
    }

    .notification.critical {
      border-color: rgba(243, 139, 168, 0.45);
    }

    .widget-dnd > switch {
      background: #313244;
      border-radius: 999px;
    }

    .widget-dnd > switch:checked {
      background: #89b4fa;
    }

    .widget-dnd > switch slider {
      background: #cdd6f4;
      border-radius: 999px;
    }
  '';
in
{
  home.packages = [
    nmAppletQuiet
    pasystrayQuiet
  ];

  services = {
    playerctld.enable = true;

    # USB 设备自动挂载服务
    udiskie = {
      enable = true;
      automount = true;
      notify = true;
      tray = "auto"; # Waybar tray 可用时显示设备托盘菜单
    };

    swaync = {
      enable = true;
      settings = swayncSettings;
      style = swayncStyle;
    };
  };

  systemd = {
    user.services =
      {
        # Polkit 认证代理（图形会话自启）
        # 无此服务时，需要权限提升的操作（virt-manager、Nautilus 挂载等）会静默失败
        polkit-gnome-authentication-agent-1 = {
          Unit = {
            Description = "polkit-gnome-authentication-agent-1";
            After = [ "graphical-session.target" ];
          };
          Install.WantedBy = [ "graphical-session.target" ];
          Service = {
            Type = "simple";
            ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
            Restart = "on-failure";
            RestartSec = 1;
            TimeoutStopSec = 10;
          };
        };

        # Clipboard history
        cliphist-daemon = {
          Unit = {
            Description = "cliphist clipboard history daemon";
            After = [ "graphical-session.target" ];
            PartOf = [ "graphical-session.target" ];
          };
          Install.WantedBy = [ "graphical-session.target" ];
          Service = {
            Type = "simple";
            ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store";
            Restart = "always";
            RestartSec = 2;
          };
        };

        waybar = {
          Unit = {
            Description = "Waybar status bar";
            After = [ "graphical-session.target" ];
            PartOf = [ "graphical-session.target" ];
          };
          Install.WantedBy = [ "graphical-session.target" ];
          Service = {
            Type = "simple";
            Environment = [
              "LANG=zh_CN.UTF-8"
              "LC_ALL=zh_CN.UTF-8"
              "LC_TIME=zh_CN.UTF-8"
            ];
            ExecStart = "${waybarLauncher}";
            Restart = "always";
            RestartSec = 2;
          };
        };

        # udiskie 在中文 locale 下会触发 Python logging format KeyError（'信息'）
        # 将其 locale 固定为 C.UTF-8，避免格式化字段被翻译。
        udiskie.Service.Environment = [
          "LANG=C.UTF-8"
          "LC_ALL=C.UTF-8"
        ];
        # systemd.exec(5): LogFilterPatterns 当前不支持 per-user services；使用 wrapper 过滤噪音。
        swaync.Service.ExecStart = lib.mkForce "${lib.getExe swayncQuiet}";
        udiskie.Service.ExecStart = lib.mkForce "${lib.getExe udiskieQuiet}";

        swaybg = {
          Unit = {
            Description = "Wallpaper daemon (swaybg)";
            After = [ "graphical-session.target" ];
            PartOf = [ "graphical-session.target" ];
          };
          Install.WantedBy = [ "graphical-session.target" ];
          Service = {
            Type = "simple";
            ExecStart = "${swaybgLauncher}";
            Restart = "on-failure";
            RestartSec = 2;
          };
        };

        provider-app-vpn-ui = lib.mkIf enableProvider appVpn {
          Unit = {
            Description = "Provider app VPN GUI";
            After = [ "graphical-session.target" ];
            PartOf = [ "graphical-session.target" ];
          };
          Install.WantedBy = [ "graphical-session.target" ];
          Service = {
            Type = "simple";
            Environment = [
              # Provider app wrapper 仅注入 coreutils/grep PATH；补齐 gsettings 与图形库搜索路径
              "PATH=${pkgs.glib}/bin:/run/current-system/sw/bin:${userProfileBin}"
              "LD_LIBRARY_PATH=${pkgs.libglvnd}/lib:/run/opengl-driver/lib:/run/opengl-driver-32/lib:/run/current-system/sw/lib"
              "LIBGL_DRIVERS_PATH=/run/opengl-driver/lib/dri"
              "GSETTINGS_SCHEMA_DIR=${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas"
            ];
            ExecStart = "${lib.getExe provider-appVpnQuiet}";
            Restart = "on-failure";
            RestartSec = 2;
          };
        };
      };
  };
}
