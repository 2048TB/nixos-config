{ mylib
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
  resolvedPrimaryDisplay = mylib.primaryDisplay hostCfg;
  expectedPrimaryDisplayName =
    if resolvedPrimaryDisplay == null then null else (resolvedPrimaryDisplay.name or null);
in
{
  "eval-${name}-generated-niri-outputs" = pkgs.runCommand "eval-${name}-generated-niri-outputs" { } ''
    test "${if (hmCfg.xdg.configFile."niri/outputs.kdl".text or "") == (mylib.mkNiriOutputs hostCfg) then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-primary-display-capability" = pkgs.runCommand "eval-${name}-primary-display-capability" { } ''
    test "${if cfg.my.capabilities.primaryDisplayName == expectedPrimaryDisplayName then "1" else "0"}" = "1"
    touch "$out"
  '';
}
