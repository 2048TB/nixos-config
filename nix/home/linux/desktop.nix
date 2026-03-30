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
  inherit (roleFlags) enableMullvadVpn;

  mkLogFilteredLauncher = mylib.mkLogFilteredLauncher pkgs;
  mkdirExe = lib.getExe' pkgs.coreutils "mkdir";
  touchExe = lib.getExe' pkgs.coreutils "touch";
  catExe = lib.getExe' pkgs.coreutils "cat";

  # ===== Log-filtered launcher 定义 =====
  udiskieLogFiltered = mkLogFilteredLauncher "udiskie-log-filtered" "${pkgs.udiskie}/bin/udiskie" [
    "gtk_widget_get_scale_factor: assertion 'GTK_IS_WIDGET \\(widget\\)' failed"
  ];
  mullvadVpnLogFiltered = mkLogFilteredLauncher "mullvad-vpn-log-filtered" "${pkgs.mullvad-vpn}/bin/mullvad-vpn" [
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
    playerctld.enable = true;

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
      rule-add = {
        ssd = [
          [ "-app-id" "'google-chrome'" ]
          [ "-app-id" "'steam'" ]
        ];
      };
      map.normal = {
        "Super Q" = "close";
        "Super Return" = "spawn ghostty";
        "Super Space" = "spawn fuzzel";
        "Super F" = "toggle-fullscreen";
        "Super+Shift Return" = "zoom";
        "Super J" = "focus-view next";
        "Super K" = "focus-view previous";
        "Super+Shift J" = "swap next";
        "Super+Shift K" = "swap previous";
        "Super H" = "send-layout-cmd rivertile \"main-ratio -0.05\"";
        "Super L" = "send-layout-cmd rivertile \"main-ratio +0.05\"";
      };
    };
    extraConfig = ''
      # Tag switching (bitmask)
      for i in $(seq 1 9); do
        tags=$((1 << (i - 1)))
        riverctl map normal Super "$i" set-focused-tags "$tags"
        riverctl map normal Super+Shift "$i" set-view-tags "$tags"
        riverctl map normal Super+Control "$i" toggle-focused-tags "$tags"
      done
      all_tags=$(((1 << 32) - 1))
      riverctl map normal Super 0 set-focused-tags "$all_tags"
      riverctl map normal Super+Shift 0 set-view-tags "$all_tags"

      # Float/fullscreen controls
      riverctl map normal Super+Shift Space toggle-float

      # Layout generator
      rivertile -view-padding 6 -outer-padding 6 &
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
            ExecStart = "${lib.getExe mullvadVpnLogFiltered}";
            Restart = "on-failure";
            RestartSec = 2;
          };
        };
      };
  };
}
