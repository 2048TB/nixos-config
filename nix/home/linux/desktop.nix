{ pkgs
, noctalia
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
  noctaliaShellPkg = noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # ===== Quiet launcher 定义 =====
  udiskieQuiet = mkLogFilteredLauncher "udiskie-quiet" "${pkgs.udiskie}/bin/udiskie" [
    "gtk_widget_get_scale_factor: assertion 'GTK_IS_WIDGET \\(widget\\)' failed"
  ];
  mullvadVpnQuiet = mkLogFilteredLauncher "mullvad-vpn-quiet" "${pkgs.mullvad-vpn}/bin/mullvad-vpn" [
    "Gtk: gtk_widget_get_scale_factor: assertion 'GTK_IS_WIDGET \\(widget\\)' failed"
  ];
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
in
{
  xdg.dataFile."applications/dev.noctalia.noctalia-qs.desktop".text =
    # portal host app registry 要求 app_id 能匹配一个可解析的 .desktop basename；
    # 上游当前未安装该文件，这里直接生成最小合法 desktop entry。
    ''
      [Desktop Entry]
      Version=1.5
      Type=Application
      Name=Noctalia Shell
      NoDisplay=true
      TryExec=${lib.getExe noctaliaShellPkg}
      Exec=${lib.getExe noctaliaShellPkg}
      Terminal=false
    '';

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
    # Noctalia 官方文档已不再推荐 systemd startup；
    # 改由 Niri 的 spawn-at-startup 拉起，避免 delayed startup / IPC 漂移。
    systemd.enable = false;
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
