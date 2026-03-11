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
  inherit (config.my) profiles;
  hibernateEnabled = hostCfg.resumeOffset != null;
  isLaptop = profiles.laptop;
  isDesktop = profiles.desktop;

  tuigreetPackage = pkgs.tuigreet or pkgs.greetd.tuigreet or (throw "tuigreet package not found in pkgs.tuigreet or pkgs.greetd.tuigreet");
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
      --cmd ${homeDir}/.wayland-session
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
    (lib.mkIf isDesktop {
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
      };
      pulseaudio.enable = false;
      blueman.enable = true;

      gvfs.enable = true;
      tumbler.enable = true;
      udisks2.enable = true;
      gnome.gnome-keyring.enable = true;
    })
    (lib.mkIf isLaptop {
      upower.enable = true;
      power-profiles-daemon.enable = true;
    })
  ];

  systemd = {
    sleep.extraConfig = lib.mkIf isLaptop ''
      AllowSuspend=yes
      AllowHibernation=${if hibernateEnabled then "yes" else "no"}
      AllowSuspendThenHibernate=${if hibernateEnabled then "yes" else "no"}
      AllowHybridSleep=no
    '';

    services = { };

    tmpfiles.rules = [
      "d ${configRepoPath} 0755 ${mainUser} ${mainUser} -"
      "L+ /etc/nixos - - - - ${configRepoPath}"
      "e ${homeDir}/.cache - - - 30d"
      "e /tmp - - - 1d"
      "e /var/tmp - - - 7d"
    ];
  };
}
