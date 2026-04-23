{ pkgs
, lib
, mylib
, myvars
, osConfig ? null
, config
, ...
}:
let
  hostCfg = import ../base/resolve-host.nix { inherit myvars osConfig; };

  mkLogFilteredLauncher = mylib.mkLogFilteredLauncher pkgs;
  homeDir = config.home.homeDirectory;
  mkdirExe = lib.getExe' pkgs.coreutils "mkdir";
  touchExe = lib.getExe' pkgs.coreutils "touch";
  catExe = lib.getExe' pkgs.coreutils "cat";
  dateExe = lib.getExe' pkgs.coreutils "date";
  dirnameExe = lib.getExe' pkgs.coreutils "dirname";
  mkfifoExe = lib.getExe' pkgs.coreutils "mkfifo";
  rmExe = lib.getExe' pkgs.coreutils "rm";
  sleepExe = lib.getExe' pkgs.coreutils "sleep";
  grepExe = lib.getExe' pkgs.gnugrep "grep";
  awkExe = lib.getExe' pkgs.gawk "awk";
  wpctlExe = lib.getExe' pkgs.wireplumber "wpctl";
  enableMiseAutoUpgrade = hostCfg.miseAutoUpgrade or false;
  kwmStatusFifo = "${homeDir}/.local/state/kwm/status.fifo";
  miseUpgrade = pkgs.writeShellScript "mise-upgrade" ''
    set -eu
    cd "$HOME"
    echo "[mise-upgrade] $(${dateExe} -Is) running: mise upgrade --yes"
    exec ${lib.getExe pkgs.mise} upgrade --yes
  '';
  kwmStatusPrepare = pkgs.writeShellScript "kwm-status-prepare" ''
    set -eu
    fifo_dir="$(${dirnameExe} ${lib.escapeShellArg kwmStatusFifo})"
    ${mkdirExe} -p "$fifo_dir"
    if [ ! -p ${lib.escapeShellArg kwmStatusFifo} ]; then
      ${rmExe} -f ${lib.escapeShellArg kwmStatusFifo}
      ${mkfifoExe} ${lib.escapeShellArg kwmStatusFifo}
    fi
  '';
  kwmStatus = pkgs.writeShellScript "kwm-status" ''
    set -eu

    battery_segment() {
      for battery in /sys/class/power_supply/BAT*; do
        [ -d "$battery" ] || continue
        capacity="$(${catExe} "$battery/capacity" 2>/dev/null || true)"
        status="$(${catExe} "$battery/status" 2>/dev/null || true)"
        [ -n "$capacity" ] || continue
        case "$status" in
          Charging) printf 'bat+ %s%%' "$capacity" ;;
          Full) printf 'bat %s%%' "$capacity" ;;
          *) printf 'bat %s%%' "$capacity" ;;
        esac
        return 0
      done
      return 1
    }

    volume_segment() {
      volume_line="$(${wpctlExe} get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || true)"
      [ -n "$volume_line" ] || return 1
      if printf '%s\n' "$volume_line" | ${grepExe} -q 'MUTED'; then
        printf 'vol mute'
        return 0
      fi
      percent="$(printf '%s\n' "$volume_line" | ${awkExe} '{ printf "%d", $2 * 100 }')"
      printf 'vol %s%%' "$percent"
    }

    while :; do
      segments=""
      if battery="$(battery_segment)"; then
        segments="$battery"
      fi
      if volume="$(volume_segment)"; then
        if [ -n "$segments" ]; then
          segments="$segments | $volume"
        else
          segments="$volume"
        fi
      fi
      clock="$(${dateExe} '+%a %m-%d %H:%M')"
      if [ -n "$segments" ]; then
        line="$segments | $clock"
      else
        line="$clock"
      fi
      printf '%s\n' "$line" > ${lib.escapeShellArg kwmStatusFifo}
      ${sleepExe} 5
    done
  '';
  swayidleStart = pkgs.writeShellScript "swayidle-start" ''
    set -eu
    exec ${lib.getExe pkgs.swayidle} -w \
      timeout 600 ${lib.escapeShellArg "${homeDir}/.config/river/lock.sh"} \
      timeout 900 ${lib.escapeShellArg "${homeDir}/.config/river/dpms-off.sh"} \
      resume ${lib.escapeShellArg "${homeDir}/.config/river/outputs.sh"} \
      before-sleep ${lib.escapeShellArg "${homeDir}/.config/river/lock.sh"} \
      after-resume ${lib.escapeShellArg "${homeDir}/.config/river/outputs.sh"}
  '';

  # ===== Log-filtered launcher 定义 =====
  udiskieLogFiltered = mkLogFilteredLauncher "udiskie-log-filtered" "${pkgs.udiskie}/bin/udiskie" [
    "gtk_widget_get_scale_factor: assertion 'GTK_IS_WIDGET \\(widget\\)' failed"
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
  nautilusX11 = pkgs.writeShellScript "nautilus-x11" ''
    set -eu

    # 保持 Nautilus 在原生 Wayland 下运行，同时固定到 fcitx GTK IM module，
    # 避免 Wayland 文本输入链路在 rename / pop-up 场景下漂移。
    export GDK_BACKEND=wayland
    export GTK_IM_MODULE=fcitx

    exec ${pkgs.nautilus}/bin/nautilus --new-window "$@"
  '';
in
{
  xdg.dataFile."applications/org.gnome.Nautilus.desktop".text =
    # 覆盖上游 desktop entry：仅对 Nautilus 定向切换到 fcitx GTK IM module，
    # 保留 Wayland fractional scaling，并避免文本输入路径回退。
    ''
      [Desktop Entry]
      Name=Files
      Comment=Access and organize files
      Exec=${nautilusX11} %U
      Icon=org.gnome.Nautilus
      Terminal=false
      Type=Application
      StartupNotify=true
      Categories=GNOME;GTK;Utility;Core;FileManager;
      MimeType=inode/directory;
      X-GNOME-UsesNotifications=true
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

        fcitx5-daemon = {
          Unit = {
            Description = "fcitx5 input method daemon";
            After = [ "graphical-session.target" ];
            PartOf = [ "graphical-session.target" ];
          };
          Service = {
            Type = "simple";
            ExecStart = "/run/current-system/sw/bin/fcitx5 -r";
            Restart = "on-failure";
            RestartSec = 1;
          };
        };

        kwm-status = {
          Unit = {
            Description = "kwm bar status writer";
            After = [ "graphical-session.target" ];
            PartOf = [ "graphical-session.target" ];
          };
          Service = {
            Type = "simple";
            ExecStartPre = "${kwmStatusPrepare}";
            ExecStart = "${kwmStatus}";
            Restart = "always";
            RestartSec = 1;
          };
        };

        swayidle = {
          Unit = {
            Description = "Idle manager for River";
            After = [ "graphical-session.target" ];
            PartOf = [ "graphical-session.target" ];
          };
          Service = {
            Type = "simple";
            ExecStart = "${swayidleStart}";
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

        mise-upgrade = {
          Unit = {
            Description = "Upgrade global mise tools";
          };
          Service = {
            Type = "oneshot";
            ExecStart = "${miseUpgrade}";
          };
        };
      };

    user.timers =
      lib.optionalAttrs enableMiseAutoUpgrade {
        mise-upgrade = {
          Unit = {
            Description = "Periodic upgrade for global mise tools (explicit opt-in)";
          };
          Timer = {
            OnCalendar = "Mon *-*-* 04:30:00";
            Persistent = true;
            RandomizedDelaySec = "1h";
            Unit = "mise-upgrade.service";
          };
          Install.WantedBy = [ "timers.target" ];
        };
      };
  };

  home = {
    activation.ensureKwmStatusFifo = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      fifo_dir="$(${dirnameExe} ${lib.escapeShellArg kwmStatusFifo})"
      ${mkdirExe} -p "$fifo_dir"
      if [ ! -p ${lib.escapeShellArg kwmStatusFifo} ]; then
        ${rmExe} -f ${lib.escapeShellArg kwmStatusFifo}
        ${mkfifoExe} ${lib.escapeShellArg kwmStatusFifo}
      fi
    '';

    sessionPath = [
      "${config.home.homeDirectory}/.local/share/mise/shims"
    ];
  };
}
