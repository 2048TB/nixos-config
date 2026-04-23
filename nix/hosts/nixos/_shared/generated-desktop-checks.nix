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
  expectedRiverOutputSetup = mylib.mkRiverOutputSetupScript hostCfg;
  actualRiverOutputSetup = hmCfg.xdg.configFile."river/outputs.sh".text or "";
  kwmConfigText = hmCfg.xdg.configFile."kwm/config.zon".text or "";
  resolvedPrimaryDisplay = mylib.primaryDisplay hostCfg;
  expectedPrimaryDisplayName =
    if resolvedPrimaryDisplay == null then null else (resolvedPrimaryDisplay.name or null);
in
{
  "eval-${name}-generated-river-output-setup" = pkgs.runCommand "eval-${name}-generated-river-output-setup" { } ''
    test "${if actualRiverOutputSetup == expectedRiverOutputSetup then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-kwm-config-present" = pkgs.runCommand "eval-${name}-kwm-config-present" { } ''
    test "${if kwmConfigText != "" then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-primary-display-capability" = pkgs.runCommand "eval-${name}-primary-display-capability" { } ''
    test "${if cfg.my.capabilities.primaryDisplayName == expectedPrimaryDisplayName then "1" else "0"}" = "1"
    touch "$out"
  '';
}
