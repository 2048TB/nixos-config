{ pkgs
, lib
, mylib
, mytheme
, myvars
, osConfig ? null
, userProfileBin
, ...
}:
let
  hostCfg = import ../base/resolve-host.nix { inherit myvars osConfig; };
  roleFlags = mylib.roleFlags hostCfg;
  inherit (roleFlags) enableMullvadVpn;

  mkLogFilteredLauncher = mylib.mkLogFilteredLauncher pkgs;

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
  mullvadVpnQuiet = mkLogFilteredLauncher "mullvad-vpn-quiet" "${pkgs.mullvad-vpn}/bin/mullvad-vpn" [
    "Gtk: gtk_widget_get_scale_factor: assertion 'GTK_IS_WIDGET \\(widget\\)' failed"
  ];
  waybarLauncher = pkgs.writeShellApplication {
    name = "waybar-launcher";
    runtimeInputs = [ pkgs.coreutils waybarQuiet ];
    text = builtins.readFile ../../scripts/session/waybar-launcher.sh;
  };
  swaybgLauncher = pkgs.writeShellApplication {
    name = "swaybg-launcher";
    runtimeInputs = with pkgs; [ coreutils findutils swaybg ];
    text = builtins.readFile ../../scripts/session/swaybg-launcher.sh;
  };

  aria2PrepareSession = pkgs.writeShellScript "aria2-prepare-session" ''
    set -eu
    mkdir -p "$HOME/.local/share/aria2"
    touch "$HOME/.local/share/aria2/session"
  '';
  aria2RpcSecretPath = "/run/secrets/services/aria2-rpc";
  aria2Start = pkgs.writeShellScript "aria2-start" ''
    set -eu
    rpc_secret_arg=""
    if [ -r "${aria2RpcSecretPath}" ]; then
      rpc_secret_arg="--rpc-secret=$(cat "${aria2RpcSecretPath}")"
    fi
    exec ${pkgs.aria2}/bin/aria2c --conf-path="$HOME/.config/aria2/aria2.conf" $rpc_secret_arg
  '';

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
    ];
    "widget-config" = {
      title = {
        text = "Notification Center";
        "clear-all-button" = true;
        "button-text" = "Clear";
      };
      dnd.text = "Do Not Disturb";
      label = {
        "max-lines" = 1;
        text = "Notification Center";
      };
      notifications = { };
    };
  };
  swayncStyle =
    let
      p = mytheme.palette;
    in
    ''
      * {
        font-family: "Maple Mono NF CN", "Sarasa UI SC", "JetBrainsMono Nerd Font", sans-serif;
        font-size: 13px;
      }

      .control-center {
        background: #${p.bg.hex};
        border: 1px solid rgba(${p.bg3.rgb}, 0.35);
        border-radius: 14px;
      }

      .control-center .widget-title,
      .control-center .widget-dnd,
      .control-center .widget-mpris {
        background: rgba(${p.bg1.rgb}, 0.5);
        border: 1px solid rgba(${p.bg3.rgb}, 0.25);
        border-radius: 10px;
        margin: 8px 10px 0 10px;
        padding: 8px 10px;
      }

      .control-center .widget-title > button {
        background: #${p.blue.hex};
        color: #${p.bg.hex};
        border-radius: 8px;
        border: none;
        padding: 4px 10px;
      }

      .notification-row:focus,
      .notification-row:hover {
        background: transparent;
      }

      .notification {
        background: #${p.bg.hex};
        border: 1px solid rgba(${p.bg3.rgb}, 0.25);
        border-radius: 12px;
        margin: 6px 10px;
        padding: 0;
      }

      .notification-content {
        padding: 8px 10px;
      }

      .notification-default-action:hover,
      .notification-action:hover {
        background: rgba(${p.blue.rgb}, 0.18);
      }

      .notification.critical {
        border-color: rgba(${p.red.rgb}, 0.45);
      }

      .widget-dnd > switch {
        background: #${p.bg1.hex};
        border-radius: 999px;
      }

      .widget-dnd > switch:checked {
        background: #${p.blue.hex};
      }

      .widget-dnd > switch slider {
        background: #${p.fg.hex};
        border-radius: 999px;
      }
    '';
in
{
  services = {
    kanshi = lib.mkIf (hostCfg.displays != [ ]) {
      enable = true;
      settings = mylib.mkKanshiSettings hostCfg;
    };

    playerctld.enable = true;

    swaync = {
      enable = true;
      settings = swayncSettings;
      style = swayncStyle;
    };

    # USB 设备自动挂载服务
    udiskie = {
      enable = true;
      automount = true;
      notify = true;
      tray = "auto"; # 状态栏托盘可用时显示设备托盘菜单
    };
  };

  wayland.windowManager.river = {
    enable = true;
    package = null;
    xwayland.enable = false;
    extraSessionVariables = {
      NIXOS_OZONE_WL = "1";
    };
    extraConfig = mytheme.apply (builtins.readFile ../configs/river/init);
  };

  systemd = {
    user.services = {
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
          ExecStart = lib.getExe waybarLauncher;
          Restart = "always";
          RestartSec = 2;
        };
      };

      swaybg = {
        Unit = {
          Description = "Wallpaper daemon (swaybg)";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Install.WantedBy = [ "graphical-session.target" ];
        Service = {
          Type = "simple";
          ExecStart = lib.getExe swaybgLauncher;
          Restart = "on-failure";
          RestartSec = 2;
        };
      };

      network-manager-applet = {
        Unit = {
          Description = "Network Manager applet";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Install.WantedBy = [ "graphical-session.target" ];
        Service = {
          Type = "simple";
          ExecStart = "${lib.getExe nmAppletQuiet} --indicator";
          Restart = "on-failure";
          RestartSec = 2;
        };
      };

      pasystray = {
        Unit = {
          Description = "PulseAudio system tray";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Install.WantedBy = [ "graphical-session.target" ];
        Service = {
          Type = "simple";
          ExecStart = lib.getExe pasystrayQuiet;
          Restart = "on-failure";
          RestartSec = 2;
        };
      };

      # udiskie 在中文 locale 下会触发 Python logging format KeyError（'信息'）
      # 将其 locale 固定为 C.UTF-8，避免格式化字段被翻译。
      udiskie.Service.Environment = [
        "LANG=C.UTF-8"
        "LC_ALL=C.UTF-8"
      ];
      swaync.Service.ExecStart = lib.mkForce "${lib.getExe swayncQuiet}";
      udiskie.Service.ExecStart = lib.mkForce "${lib.getExe udiskieQuiet}";

      aria2 = {
        Unit = {
          Description = "aria2 RPC daemon";
        };
        Install.WantedBy = [ "default.target" ];
        Service = {
          Type = "simple";
          ExecStartPre = "${aria2PrepareSession}";
          ExecStart = "${aria2Start}";
          Restart = "on-failure";
          RestartSec = 2;
        };
      };

      mullvad-vpn-ui = lib.mkIf enableMullvadVpn {
        Unit = {
          Description = "Mullvad VPN GUI";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Install.WantedBy = [ "graphical-session.target" ];
        Service = {
          Type = "simple";
          Environment = [
            # Mullvad wrapper 仅注入 coreutils/grep PATH；补齐 gsettings 与图形库搜索路径
            "PATH=${pkgs.glib}/bin:/run/current-system/sw/bin:${userProfileBin}"
            "LD_LIBRARY_PATH=${pkgs.libglvnd}/lib:/run/opengl-driver/lib:/run/opengl-driver-32/lib:/run/current-system/sw/lib"
            "LIBGL_DRIVERS_PATH=/run/opengl-driver/lib/dri"
            "GSETTINGS_SCHEMA_DIR=${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas"
          ];
          ExecStart = "${lib.getExe mullvadVpnQuiet}";
          Restart = "on-failure";
          RestartSec = 2;
        };
      };
    };
  };
}
