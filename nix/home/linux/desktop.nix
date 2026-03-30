{ pkgs
, lib
, mylib
, myvars
, osConfig ? null
, userProfileBin
, ...
}:
let
  hostCfg = import ../base/resolve-host.nix { inherit myvars osConfig; };
  roleFlags = mylib.roleFlags hostCfg;
  inherit (roleFlags) enableProvider appVpn;

  mkLogFilteredLauncher = mylib.mkLogFilteredLauncher pkgs;
  mkdirExe = lib.getExe' pkgs.coreutils "mkdir";
  touchExe = lib.getExe' pkgs.coreutils "touch";
  catExe = lib.getExe' pkgs.coreutils "cat";

  # ===== Log-filtered launcher 定义 =====
  udiskieLogFiltered = mkLogFilteredLauncher "udiskie-log-filtered" "${pkgs.udiskie}/bin/udiskie" [
    "gtk_widget_get_scale_factor: assertion 'GTK_IS_WIDGET \\(widget\\)' failed"
  ];
  provider-appVpnLogFiltered = mkLogFilteredLauncher "provider-app-vpn-log-filtered" "${pkgs.provider-app-vpn}/bin/provider-app-vpn" [
    "Gtk: gtk_widget_get_scale_factor: assertion 'GTK_IS_WIDGET \\(widget\\)' failed"
  ];
  aria2PrepareSession = pkgs.writeShellScript "aria2-prepare-session" ''
    set -eu
    ${mkdirExe} -p "$HOME/.local/share/aria2"
    ${touchExe} "$HOME/.local/share/aria2/session"
  '';
  aria2RpcSecretPath = "/run/secrets/services/aria2-rpc";
  aria2Start = pkgs.writeShellScript "aria2-start" ''
    set -eu
    rpc_secret_arg=""
    if [ -r "${aria2RpcSecretPath}" ]; then
      rpc_secret_arg="--rpc-secret=$(${catExe} "${aria2RpcSecretPath}")"
    fi
    exec ${pkgs.aria2}/bin/aria2c --conf-path="$HOME/.config/aria2/aria2.conf" $rpc_secret_arg
  '';
in
{
  services = {
    kanshi = {
      enable = true;
      systemdTarget = "river-session.target";
    };

    playerctld.enable = true;

    swaync = {
      enable = true;
    };

    # USB 设备自动挂载服务
    udiskie = {
      enable = true;
      automount = true;
      notify = true;
      tray = "auto"; # 状态栏托盘可用时显示设备托盘菜单
    };
  };

  programs.waybar = {
    enable = true;
    systemd = {
      enable = true;
      target = "river-session.target";
    };
  };

  wayland.windowManager.river = {
    enable = true;
    package = null; # NixOS programs.river-classic 提供安装
    # river 由 system profile 提供；显式禁用 HM 的 xwayland 包注入，
    # 避免与系统侧 programs.river-classic.xwayland.enable 产生重复 closure。
    xwayland.enable = false;
    # 显式固定 HM 的 systemd 集成，避免未来默认值变化影响 graphical-session 链路。
    systemd = {
      enable = true;
      variables = [
        "DISPLAY" "WAYLAND_DISPLAY" "XDG_CURRENT_DESKTOP"
        "NIXOS_OZONE_WL" "XCURSOR_THEME" "XCURSOR_SIZE"
        "QT_QPA_PLATFORMTHEME"
        "INPUT_METHOD" "GTK_IM_MODULE" "QT_IM_MODULE" "XMODIFIERS" "SDL_IM_MODULE"
      ];
    };
    settings = {
      border-width = 2;
      set-repeat = "50 300";
      default-layout = "rivertile";
      focus-follows-cursor = "normal";
      set-cursor-warp = "on-focus-change";

      # SSD 规则：这些应用的装饰由 compositor 绘制
      rule-add = {
        ssd = [
          [ "-app-id" "'google-chrome'" ]
          [ "-app-id" "'steam'" ]
          [ "-app-id" "'virt-manager'" ]
        ];
        float = [
          [ "-app-id" "'pavucontrol'" ]
          [ "-app-id" "'nm-connection-editor'" ]
          [ "-app-id" "'imv'" ]
          [ "-app-id" "'nomacs'" ]
          [ "-app-id" "'org.gnome.FileRoller'" ]
          [ "-app-id" "'ghostty-float'" ]
        ];
      };

      map = {
        normal = {
          # ===== 窗口管理 =====
          "Super Q" = "close";                       # niri: Mod+Q
          "Super Z" = "toggle-fullscreen";           # 全屏
          "Super W" = "toggle-float";                # 浮动切换（niri: Mod+W）
          "Super E" = "focus-view next";             # 浮动/平铺焦点切换

          # ===== 焦点移动（方向键）=====
          "Super Left" = "focus-view previous";
          "Super Down" = "focus-view next";
          "Super Up" = "focus-view previous";
          "Super Right" = "focus-view next";

          # ===== 窗口位置移动（SDFG）=====
          "Super S" = "swap previous";               # 左移
          "Super D" = "swap next";                    # 下移
          "Super F" = "swap previous";               # 上移
          "Super G" = "swap next";                    # 右移

          # ===== 布局比例 =====
          "Super R" = "send-layout-cmd rivertile \"main-ratio -0.05\"";  # 缩小主区
          "Super T" = "send-layout-cmd rivertile \"main-ratio +0.05\"";  # 放大主区
          "Super+Shift R" = "send-layout-cmd rivertile \"main-count +1\""; # 主区数量 +1
          "Super+Shift T" = "send-layout-cmd rivertile \"main-count -1\""; # 主区数量 -1

          # ===== 核心操作（XCVB）=====
          "Super X" = "zoom";                        # 提升为主窗口
          "Super C" = "focus-output next";            # 焦点切换到下一输出
          "Super V" = "spawn 'cliphist list | fuzzel -d | cliphist decode | wl-copy'"; # 剪贴板历史
          "Super B" = "send-to-output next";          # 发送窗口到下一输出

          # ===== 程序启动（对齐 niri）=====
          "Super Return" = "spawn ghostty";          # niri: Mod+Return
          "Super Space" = "spawn fuzzel";            # niri: Mod+Space

          # ===== 会话管理（对齐 niri）=====
          "Super+Shift E" = "spawn wlogout";         # niri: Mod+Shift+E
          "Super+Shift L" = "spawn 'swaylock -f --clock --indicator --effect-blur 7x5'"; # niri: Mod+Shift+L
          "Super+Shift P" = "spawn 'riverctl output \"*\" power off'"; # niri: Mod+Shift+P

          # ===== 截图（对齐 niri）=====
          "None Print" = "spawn 'grim - | wl-copy'";
          "Super+Shift A" = "spawn 'grim -g \"$(slurp)\" - | wl-copy'";

          # ===== 音量控制 =====
          "None XF86AudioRaiseVolume" = "spawn 'wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.02+ --limit 1.0'";
          "None XF86AudioLowerVolume" = "spawn 'wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.02-'";
          "None XF86AudioMute" = "spawn 'wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle'";
          "None XF86AudioMicMute" = "spawn 'wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle'";

          # ===== 媒体控制 =====
          "None XF86AudioPlay" = "spawn 'playerctl play-pause'";
          "None XF86AudioStop" = "spawn 'playerctl stop'";
          "None XF86AudioPrev" = "spawn 'playerctl previous'";
          "None XF86AudioNext" = "spawn 'playerctl next'";

          # ===== 亮度控制 =====
          "None XF86MonBrightnessUp" = "spawn 'brightnessctl --class=backlight set 1%+'";
          "None XF86MonBrightnessDown" = "spawn 'brightnessctl --class=backlight set 1%-'";

          # ===== 通知中心 =====
          "Super N" = "spawn 'swaync-client -t -sw'";
        };

        # 锁屏模式下的键位（音量/媒体）
        locked = {
          "None XF86AudioRaiseVolume" = "spawn 'wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.02+ --limit 1.0'";
          "None XF86AudioLowerVolume" = "spawn 'wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.02-'";
          "None XF86AudioMute" = "spawn 'wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle'";
          "None XF86AudioPlay" = "spawn 'playerctl play-pause'";
          "None XF86AudioPrev" = "spawn 'playerctl previous'";
          "None XF86AudioNext" = "spawn 'playerctl next'";
        };
      };
    };
    extraConfig = ''
      # ===== Tag 切换（bitmask，对齐 niri Mod+1~9 工作区）=====
      for i in $(seq 1 9); do
        tags=$((1 << (i - 1)))
        riverctl map normal Super "$i" set-focused-tags "$tags"
        riverctl map normal Super+Shift "$i" set-view-tags "$tags"
        riverctl map normal Super+Control "$i" toggle-focused-tags "$tags"
      done
      all_tags=$(((1 << 32) - 1))
      riverctl map normal Super 0 set-focused-tags "$all_tags"
      riverctl map normal Super+Shift 0 set-view-tags "$all_tags"

      # ===== 鼠标绑定 =====
      riverctl map-pointer normal Super BTN_LEFT move-view
      riverctl map-pointer normal Super BTN_RIGHT resize-view
      riverctl map-pointer normal Super BTN_MIDDLE toggle-float

      # ===== Layout generator（主区占 80%）=====
      rivertile -view-padding 6 -outer-padding 6 -main-ratio 0.8 &
    '';
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
            PartOf = [ "graphical-session.target" ];
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

        # Fcitx5 输入法守护进程（River 需要显式启动，Niri 由 compositor 自动拉起）
        fcitx5-daemon = {
          Unit = {
            Description = "Fcitx5 Input Method";
            After = [ "graphical-session.target" ];
            PartOf = [ "graphical-session.target" ];
          };
          Install.WantedBy = [ "graphical-session.target" ];
          Service = {
            Type = "simple";
            ExecStart = "/run/current-system/sw/bin/fcitx5 --replace";
            Restart = "on-failure";
            RestartSec = 1;
          };
        };

        # udiskie 在中文 locale 下会触发 Python logging format KeyError（'信息'）
        # 将其 locale 固定为 C.UTF-8，避免格式化字段被翻译。
        udiskie.Service.Environment = [
          "LANG=C.UTF-8"
          "LC_ALL=C.UTF-8"
        ];
        udiskie.Service.ExecStart = lib.mkForce "${lib.getExe udiskieLogFiltered}";

        aria2 = {
          Unit = {
            Description = "aria2 RPC daemon";
            After = [ "network-online.target" ];
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

        swaybg = {
          Unit = {
            Description = "Wallpaper daemon for Wayland";
            After = [ "graphical-session.target" ];
            PartOf = [ "graphical-session.target" ];
          };
          Install.WantedBy = [ "graphical-session.target" ];
          Service = {
            Type = "simple";
            ExecStart = "${pkgs.swaybg}/bin/swaybg -i %h/.config/wallpapers/1.png -m fill";
            Restart = "on-failure";
            RestartSec = 2;
          };
        };

        swayidle = {
          Unit = {
            Description = "Idle manager for Wayland";
            After = [ "graphical-session.target" ];
            PartOf = [ "graphical-session.target" ];
          };
          Install.WantedBy = [ "graphical-session.target" ];
          Service = {
            Type = "simple";
            ExecStart = builtins.concatStringsSep " " [
              "${pkgs.swayidle}/bin/swayidle -w"
              "timeout 300 '${pkgs.swaylock-effects}/bin/swaylock -f'"
              "timeout 600 'riverctl output \"*\" power off'"
              "resume 'riverctl output \"*\" power on'"
            ];
            Restart = "on-failure";
            RestartSec = 2;
          };
        };

        cliphist-daemon = {
          Unit = {
            Description = "Clipboard history daemon";
            After = [ "graphical-session.target" ];
            PartOf = [ "graphical-session.target" ];
          };
          Install.WantedBy = [ "graphical-session.target" ];
          Service = {
            Type = "simple";
            ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store";
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
            ExecStart = "${lib.getExe provider-appVpnLogFiltered}";
            Restart = "on-failure";
            RestartSec = 2;
          };
        };
      };
  };
}
