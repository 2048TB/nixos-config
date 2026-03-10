{ pkgs, vars, ... }:
let
  mullvad = vars.mullvad or { };
  autoConnect = mullvad.autoConnect or true;
  allowLan = mullvad.allowLan or false;
  lockdownMode = mullvad.lockdownMode or false;
  enableEarlyBootBlocking = mullvad.enableEarlyBootBlocking or false;
  mullvadCli = "${pkgs.mullvad-vpn}/bin/mullvad";
  applySettings = pkgs.writeShellScript "mullvad-apply-settings" ''
    set -eu

    for _ in $(seq 1 30); do
      if ${mullvadCli} auto-connect get >/dev/null 2>&1; then
        break
      fi
      sleep 1
    done

    ${mullvadCli} auto-connect set ${if autoConnect then "on" else "off"}
    ${mullvadCli} lan set ${if allowLan then "allow" else "block"}
    ${mullvadCli} lockdown-mode set ${if lockdownMode then "on" else "off"}
  '';
in
{
  services.mullvad-vpn = {
    enable = true;
    package = pkgs.mullvad-vpn;
    inherit enableEarlyBootBlocking;
  };

  systemd.services.mullvad-apply-settings = {
    description = "Apply declarative Mullvad settings";
    wantedBy = [ "multi-user.target" ];
    wants = [ "mullvad-daemon.service" ];
    after = [ "mullvad-daemon.service" ];
    restartTriggers = [ applySettings ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = applySettings;
    };
  };
}
