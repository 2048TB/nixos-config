{ pkgs
, lib
, mainUser
, config
, configRepoPath
, ...
}:
let
  hostCfg = config.my.host;
  homeDir = "/home/${mainUser}";
  hibernateEnabled = hostCfg.resumeOffset != null;
  inherit (config.my.capabilities) isLaptop hasDesktopSession hasFingerprintReader;
  inherit (hostCfg) desktopProfile;
  waylandSessionsDir = "${config.services.displayManager.sessionData.desktops}/share/wayland-sessions";
  desktopExec =
    if desktopProfile == "river" then
      lib.getExe pkgs.river-kwm-session
    else
      throw "Unsupported Linux desktopProfile '${desktopProfile}'";
  waylandSessionEnvSync = pkgs.writeShellScriptBin "wayland-session-env-sync" ''
    set -u

    # compositor autostart 阶段再导入显示变量；此时 WAYLAND_DISPLAY/DISPLAY
    # 已由 compositor/session wrapper 写入环境，比 greetd pre-exec 阶段更完整。
    for _ in $(${pkgs.coreutils}/bin/seq 1 40); do
      if [ -n "''${WAYLAND_DISPLAY:-}" ] || [ -n "''${DISPLAY:-}" ]; then
        break
      fi
      ${pkgs.coreutils}/bin/sleep 0.25
    done

    export XDG_SESSION_TYPE="''${XDG_SESSION_TYPE:-wayland}"
    export XDG_CURRENT_DESKTOP="''${XDG_CURRENT_DESKTOP:-${desktopProfile}}"
    export XDG_SESSION_DESKTOP="''${XDG_SESSION_DESKTOP:-${desktopProfile}}"

    /run/current-system/sw/bin/systemctl --user import-environment \
      WAYLAND_DISPLAY DISPLAY \
      XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP || true
    /run/current-system/sw/bin/dbus-update-activation-environment --systemd \
      WAYLAND_DISPLAY DISPLAY \
      XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP || true
  '';
  tuigreetPackage = pkgs.tuigreet or pkgs.greetd.tuigreet or (throw "tuigreet package not found in pkgs.tuigreet or pkgs.greetd.tuigreet");
  waylandSessionCommand = pkgs.writeShellScript "wayland-session" ''
    hm_vars="/etc/profiles/per-user/${mainUser}/etc/profile.d/hm-session-vars.sh"
    if [ -f "$hm_vars" ]; then
      # shellcheck disable=SC1090
      . "$hm_vars"
    fi

    # greetd 启动链路下，systemd user 可能不会自动继承 HM session vars。
    # 显式导入最小 GUI activation 变量，确保 user service / D-Bus 激活应用
    # 与交互式会话在输入法、Wayland/Ozone、Qt 主题、portal 发现上保持一致。
    export XDG_CURRENT_DESKTOP="''${XDG_CURRENT_DESKTOP:-${desktopProfile}}"
    export XDG_SESSION_DESKTOP="''${XDG_SESSION_DESKTOP:-${desktopProfile}}"
    export XDG_SESSION_TYPE="''${XDG_SESSION_TYPE:-wayland}"
    /run/current-system/sw/bin/systemctl --user import-environment \
      QT_IM_MODULE SDL_IM_MODULE \
      NIXOS_OZONE_WL QT_QPA_PLATFORMTHEME NIX_XDG_DESKTOP_PORTAL_DIR \
      XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE || true
    /run/current-system/sw/bin/dbus-update-activation-environment --systemd \
      QT_IM_MODULE SDL_IM_MODULE \
      NIXOS_OZONE_WL QT_QPA_PLATFORMTHEME NIX_XDG_DESKTOP_PORTAL_DIR \
      XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE || true

    if [ "$#" -gt 0 ]; then
      exec /run/current-system/sw/bin/systemd-cat -t wayland-session "$@"
    fi

    exec /run/current-system/sw/bin/systemd-cat -t wayland-session ${desktopExec}
  '';
  tuigreetCommand = pkgs.writeShellScript "greetd-tuigreet-session" ''
    exec ${lib.getExe tuigreetPackage} \
      --time \
      --time-format '%a %Y-%m-%d %H:%M:%S' \
      --remember \
      --remember-session \
      --asterisks \
      --greeting 'NixOS ${hostCfg.hostname} login' \
      --sessions ${lib.escapeShellArg waylandSessionsDir} \
      --session-wrapper ${lib.escapeShellArg waylandSessionCommand} \
      --power-shutdown '${pkgs.systemd}/bin/systemctl poweroff' \
      --power-reboot '${pkgs.systemd}/bin/systemctl reboot'
  '';
in
{
  environment.systemPackages = lib.mkIf hasDesktopSession [
    waylandSessionEnvSync
  ];

  services = lib.mkMerge [
    {
      # 日志保留策略：/var/log 已持久化，限制总量防止磁盘占满
      journald.extraConfig = ''
        SystemMaxUse=2G
        MaxRetentionSec=30day
      '';
      logind.settings = lib.mkIf isLaptop {
        Login = {
          HandleLidSwitch = if hibernateEnabled then "suspend-then-hibernate" else "suspend";
          HandleLidSwitchExternalPower = "ignore";
          HandleLidSwitchDocked = "ignore";
        };
      };
    }
    (lib.mkIf hasDesktopSession {
      xserver.enable = false;

      greetd = {
        enable = true;
        useTextGreeter = true;
        settings.default_session = {
          user = "greeter";
          command = "${tuigreetCommand}";
        };
      };

      pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        # nix-gaming pipewireLowLatency 模块已导入；
        # quantum=64 过于激进易爆音，256（~5.3ms）在游戏与日常音频间取得平衡。
        lowLatency = {
          enable = true;
          quantum = 256;
          rate = 48000;
        };
      };
      pulseaudio.enable = false;
      blueman.enable = true;

      gvfs.enable = true;
      tumbler.enable = true;
      udisks2.enable = true;
      gnome.gnome-keyring.enable = true;
      upower.enable = true;
      power-profiles-daemon.enable = true;

      # OOM 保护：内存耗尽前主动终止低优先级进程，防止系统卡死
      earlyoom = {
        enable = true;
        freeMemThreshold = 5; # 可用内存低于 5% 时触发
        freeSwapThreshold = 10; # 可用 swap 低于 10% 时触发
      };
    })
    (lib.mkIf hasFingerprintReader {
      fprintd.enable = true;
    })
  ];

  systemd = {
    sleep.extraConfig = lib.mkIf isLaptop ''
      AllowSuspend=yes
      AllowHibernation=${if hibernateEnabled then "yes" else "no"}
      AllowSuspendThenHibernate=${if hibernateEnabled then "yes" else "no"}
      AllowHybridSleep=no
    '';

    tmpfiles.rules = [
      "d ${configRepoPath} 0755 ${mainUser} ${mainUser} -"
      "L+ /etc/nixos - - - - ${configRepoPath}"
      "L+ /usr/bin/bwrap - - - - /run/wrappers/bin/bwrap"
      # Playwright 等工具按 Debian 路径查找 Chrome
      "d /opt/google/chrome 0755 root root -"
      "L+ /opt/google/chrome/chrome - - - - /etc/profiles/per-user/${mainUser}/bin/google-chrome-stable"
      "e ${homeDir}/.cache - - - 30d"
      "e /tmp - - - 1d"
      "e /var/tmp - - - 7d"
    ];
  };
}
