{ mylib
, lib
, pkgs
, name
, mainUser
, nixosSystem
, ...
}:
let
  cfg = nixosSystem.config;
  hostCfg = cfg.my.host;
  hmCfg = cfg.home-manager.users.${mainUser};
  wlogoutLayoutLib = import ../../../lib/wlogout-layout.nix { inherit lib; };
  resolvedPrimaryDisplay = mylib.primaryDisplay hostCfg;
  expectedPrimaryDisplayName =
    if resolvedPrimaryDisplay == null then null else (resolvedPrimaryDisplay.name or null);
  expectedWlogoutLayout =
    wlogoutLayoutLib.mkWlogoutLayout { supportsHibernate = (hostCfg.resumeOffset or null) != null; };
in
{
  "eval-${name}-generated-kanshi-config" = pkgs.runCommand "eval-${name}-generated-kanshi-config" { } ''
    test "${if (hmCfg.xdg.configFile."kanshi/config".text or "") == (mylib.mkKanshiConfig hostCfg) then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-primary-display-capability" = pkgs.runCommand "eval-${name}-primary-display-capability" { } ''
    test "${if cfg.my.capabilities.primaryDisplayName == expectedPrimaryDisplayName then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-generated-wlogout-layout" = pkgs.runCommand "eval-${name}-generated-wlogout-layout" { } ''
    test "${if (hmCfg.xdg.configFile."wlogout/layout".text or "") == expectedWlogoutLayout then "1" else "0"}" = "1"
    touch "$out"
  '';
}
