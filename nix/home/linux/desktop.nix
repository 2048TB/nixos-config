{ pkgs
, noctalia
, lib
, mylib
, myvars
, userProfileBin
, ...
}:
let
  roleFlags = mylib.roleFlags myvars;
  inherit (roleFlags) enableProvider appVpn;

  mkLogFilteredLauncher = mylib.mkLogFilteredLauncher pkgs;
  noctaliaShellPkg = noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # ===== Quiet launcher 定义 =====
  udiskieQuiet = mkLogFilteredLauncher "udiskie-quiet" "${pkgs.udiskie}/bin/udiskie" [
    "gtk_widget_get_scale_factor: assertion 'GTK_IS_WIDGET \\(widget\\)' failed"
  ];
  provider-appVpnQuiet = mkLogFilteredLauncher "provider-app-vpn-quiet" "${pkgs.provider-app-vpn}/bin/provider-app-vpn" [
    "Gtk: gtk_widget_get_scale_factor: assertion 'GTK_IS_WIDGET \\(widget\\)' failed"
  ];
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

  programs.noctalia-shell = {
    enable = true;
    package = noctaliaShellPkg;
    # 官方 HM 模块负责生成/管理 noctalia-shell.service
    systemd.enable = true;
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

        # udiskie 在中文 locale 下会触发 Python logging format KeyError（'信息'）
        # 将其 locale 固定为 C.UTF-8，避免格式化字段被翻译。
        udiskie.Service.Environment = [
          "LANG=C.UTF-8"
          "LC_ALL=C.UTF-8"
        ];
        udiskie.Service.ExecStart = lib.mkForce "${lib.getExe udiskieQuiet}";

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
