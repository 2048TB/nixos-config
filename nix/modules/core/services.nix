{ pkgs
, lib
, mylib
, myvars
, mytheme
, mainUser
, ...
}:
let
  homeDir = "/home/${mainUser}";
  inherit (myvars) configRepoPath;
  roleFlags = mylib.roleFlags myvars;
  inherit (roleFlags) enableMullvadVpn;
  journaldSystemMaxUse = myvars.journaldSystemMaxUse or "512M";
  journaldRuntimeMaxUse = myvars.journaldRuntimeMaxUse or "256M";

  tuigreetPackage = pkgs.tuigreet or pkgs.greetd.tuigreet;
  tuigreetTheme = let p = mytheme.palette; in
    "border=#${p.bg3.hex};text=#${p.fg.hex};prompt=#${p.blue.hex};time=#${p.fg.hex};action=#${p.blue.hex};"
    + "button=#${p.green.hex};container=#${p.bg.hex};input=#${p.yellow.hex};greet=#${p.cyan.hex};title=#${p.deep.hex}";
  tuigreetCommand = pkgs.writeShellScript "greetd-tuigreet-session" ''
    exec ${lib.getExe tuigreetPackage} \
      --time \
      --time-format '%a %Y-%m-%d %H:%M:%S' \
      --remember \
      --remember-session \
      --asterisks \
      --greeting 'NixOS ${myvars.hostname} login' \
      --width 92 \
      --window-padding 5 \
      --container-padding 4 \
      --prompt-padding 2 \
      --greet-align center \
      --theme '${tuigreetTheme}' \
      --power-shutdown '${pkgs.systemd}/bin/systemctl poweroff' \
      --power-reboot '${pkgs.systemd}/bin/systemctl reboot' \
      --cmd ${homeDir}/.wayland-session
  '';

  # 部分 Electron 应用（如 Mullvad）会在空 PATH 环境里调用 `gsettings`。
  gsettingsCompatWrapper = pkgs.writeShellScript "gsettings-compat" ''
    export GSETTINGS_SCHEMA_DIR="${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas"
    exec ${pkgs.glib}/bin/gsettings "$@"
  '';

  mkLogFilteredLauncher = mylib.mkLogFilteredLauncher pkgs;
  wireplumberQuietLauncher = mkLogFilteredLauncher "wireplumber-quiet-launcher" "${pkgs.wireplumber}/bin/wireplumber" [
    "wp_event_dispatcher_unregister_hook: assertion 'already_registered_dispatcher == self' failed"
    "wp-event-dispatcher: wp_event_dispatcher_unregister_hook: assertion 'already_registered_dispatcher == self' failed"
    "wp-event-dispatcher: <WpAsyncEventHook:.*> failed: failed to activate item: Object activation aborted: proxy destroyed"
  ];
in
{
  services = {
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
      lowLatency.enable = true;
      extraConfig.pipewire."10-disable-rtportal" = {
        "module.rt.args" = {
          "rtportal.enabled" = false;
        };
      };
      extraConfig.pipewire-pulse."10-disable-rtportal" = {
        "module.rt.args" = {
          "rtportal.enabled" = false;
        };
      };
      wireplumber.extraConfig."10-disable-libcamera-monitor"."wireplumber.profiles" = {
        main."monitor.libcamera" = "disabled";
      };
    };
    pulseaudio.enable = false;
    upower.enable = true;

    gvfs.enable = true;
    tumbler.enable = true;
    udisks2.enable = true;

    gnome.gnome-keyring.enable = true;

    journald.extraConfig = ''
      SystemMaxUse=${journaldSystemMaxUse}
      RuntimeMaxUse=${journaldRuntimeMaxUse}
    '';
  };

  systemd = {
    services = {
      systemd-machine-id-commit.enable = false;
      NetworkManager-wait-online.enable = false;

      mullvad-daemon = lib.mkIf enableMullvadVpn {
        serviceConfig = {
          ExecStartPre = pkgs.writeShellScript "disable-mullvad-lockdown" ''
            settings_dir="/etc/mullvad-vpn"
            settings_file="$settings_dir/settings.json"
            mkdir -p "$settings_dir"
            if [ ! -f "$settings_file" ]; then
              echo '{}' > "$settings_file"
            fi

            if ${pkgs.jq}/bin/jq '.block_when_disconnected = false | .auto_connect = true' "$settings_file" > "$settings_file.tmp"; then
              mv "$settings_file.tmp" "$settings_file"
              echo "Mullvad autoconnect 已启用，lockdown mode 已禁用"
            else
              rm -f "$settings_file.tmp"
              echo "WARNING: Failed to update Mullvad settings (invalid JSON). Keeping existing file." >&2
            fi
          '';
        };
      };

      nscd = {
        after = [ "systemd-tmpfiles-setup.service" ];
        wants = [ "systemd-tmpfiles-setup.service" ];
      };

      upower.wantedBy = [ "multi-user.target" ];
    };

    user.services = {
      wireplumber.serviceConfig.ExecStart = lib.mkForce [
        ""
        (lib.getExe wireplumberQuietLauncher)
      ];
    };

    tmpfiles.rules = [
      "L+ /var/run - - - - /run"
      "L+ /bin/bash - - - - /run/current-system/sw/bin/bash"
      "d /no-such-path 0755 root root -"
      "L+ /usr/bin/gsettings - - - - ${gsettingsCompatWrapper}"
      "L+ /no-such-path/gsettings - - - - ${gsettingsCompatWrapper}"
      "d ${configRepoPath} 0755 ${mainUser} ${mainUser} -"
      "L+ /etc/nixos - - - - ${configRepoPath}"
      "e ${homeDir}/.cache - - - 30d"
      "e /tmp - - - 1d"
      "e /var/tmp - - - 7d"
    ];
  };
}
