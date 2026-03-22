{ pkgs
, lib
, mainUser
, config
, configRepoPath
, mylib
, ...
}:
let
  hostCfg = config.my.host;
  roleFlags = mylib.roleFlags hostCfg;
  homeDir = "/home/${mainUser}";
  hibernateEnabled = hostCfg.resumeOffset != null;
  inherit (config.my.capabilities) isLaptop hasDesktopSession hasFingerprintReader;
  inherit (roleFlags) enableMullvadVpn;
  desktopProfile = hostCfg.desktopProfile or "niri";
  desktopSessionName = if desktopProfile == "niri" then "niri" else desktopProfile;
  desktopExec =
    if desktopProfile == "niri" then
      "/run/current-system/sw/bin/niri-session"
    else
      throw "Unsupported Linux desktopProfile '${desktopProfile}'";
  mkdirExe = lib.getExe' pkgs.coreutils "mkdir";
  mvExe = lib.getExe' pkgs.coreutils "mv";
  rmExe = lib.getExe' pkgs.coreutils "rm";

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
    export XDG_CURRENT_DESKTOP="''${XDG_CURRENT_DESKTOP:-${desktopSessionName}}"
    export XDG_SESSION_DESKTOP="''${XDG_SESSION_DESKTOP:-${desktopSessionName}}"
    /run/current-system/sw/bin/systemctl --user import-environment \
      QT_IM_MODULE SDL_IM_MODULE \
      NIXOS_OZONE_WL QT_QPA_PLATFORMTHEME NIX_XDG_DESKTOP_PORTAL_DIR \
      XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP || true
    /run/current-system/sw/bin/dbus-update-activation-environment --systemd \
      QT_IM_MODULE SDL_IM_MODULE \
      NIXOS_OZONE_WL QT_QPA_PLATFORMTHEME NIX_XDG_DESKTOP_PORTAL_DIR \
      XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP || true

    exec ${desktopExec}
  '';
  tuigreetCommand = pkgs.writeShellScript "greetd-tuigreet-session" ''
    exec ${lib.getExe tuigreetPackage} \
      --time \
      --time-format '%a %Y-%m-%d %H:%M:%S' \
      --remember \
      --remember-session \
      --asterisks \
      --greeting 'NixOS ${hostCfg.hostname} login' \
      --power-shutdown '${pkgs.systemd}/bin/systemctl poweroff' \
      --power-reboot '${pkgs.systemd}/bin/systemctl reboot' \
      --cmd ${waylandSessionCommand}
  '';
in
{
  services = lib.mkMerge [
    {
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

    services = lib.mkMerge [
      (lib.mkIf enableMullvadVpn {
        mullvad-daemon.serviceConfig.ExecStartPre = pkgs.writeShellScript "mullvad-prestart-settings" ''
          settings_dir="/etc/mullvad-vpn"
          settings_file="$settings_dir/settings.json"

          ${mkdirExe} -p "$settings_dir"
          if [ ! -f "$settings_file" ]; then
            echo '{}' > "$settings_file"
          fi

          if ${pkgs.jq}/bin/jq '.block_when_disconnected = true | .auto_connect = true | .allow_lan = true' "$settings_file" > "$settings_file.tmp"; then
            ${mvExe} "$settings_file.tmp" "$settings_file"
          else
            ${rmExe} -f "$settings_file.tmp"
            echo "WARNING: Failed to update Mullvad settings (invalid JSON). Keeping existing file." >&2
          fi
        '';
      })
    ];

    tmpfiles.rules = [
      "d ${configRepoPath} 0755 ${mainUser} ${mainUser} -"
      "L+ /etc/nixos - - - - ${configRepoPath}"
      "e ${homeDir}/.cache - - - 30d"
      "e /tmp - - - 1d"
      "e /var/tmp - - - 7d"
    ];
  };
}
