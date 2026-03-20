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
  baseNoctaliaSettings = builtins.fromJSON (builtins.readFile ../../../home/configs/noctalia/settings.json);
  baseNoctaliaWidgetsTemplate =
    let
      monitorWidgets = baseNoctaliaSettings.desktopWidgets.monitorWidgets or [ ];
    in
    if monitorWidgets == [ ] then [ ] else (builtins.head monitorWidgets).widgets;
  expectedNoctaliaSettings =
    builtins.toJSON (
      baseNoctaliaSettings
      // {
        desktopWidgets =
          (baseNoctaliaSettings.desktopWidgets or { })
          // {
            monitorWidgets = mylib.mkNoctaliaMonitorWidgets {
              host = hostCfg;
              widgetsTemplate = baseNoctaliaWidgetsTemplate;
            };
          };
      }
    );
  resolvedPrimaryDisplay = mylib.primaryDisplay hostCfg;
  expectedPrimaryDisplayName =
    if resolvedPrimaryDisplay == null then null else (resolvedPrimaryDisplay.name or null);
  syntheticDisplayHost = {
    displays = [
      {
        name = "DP-1";
        primary = true;
      }
      {
        name = "HDMI-A-1";
      }
    ];
  };
  syntheticWidgetsTemplate = [
    { id = "Clock"; }
    { id = "Weather"; }
  ];
  syntheticMonitorWidgets = mylib.mkNoctaliaMonitorWidgets {
    host = syntheticDisplayHost;
    widgetsTemplate = syntheticWidgetsTemplate;
  };
  noctaliaTextAttr = hmCfg.xdg.configFile."noctalia/settings.json".text or null;
  noctaliaIsGenerated = noctaliaTextAttr != null;
  generatedNoctaliaConfig =
    if noctaliaIsGenerated
    then builtins.fromJSON noctaliaTextAttr
    else { };
  generatedMonitorWidgets = generatedNoctaliaConfig.desktopWidgets.monitorWidgets or [ ];
in
{
  "eval-${name}-generated-niri-outputs" = pkgs.runCommand "eval-${name}-generated-niri-outputs" { } ''
    test "${if (hmCfg.xdg.configFile."niri/outputs.kdl".text or "") == (mylib.mkNiriOutputs hostCfg) then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-generated-noctalia-settings" = pkgs.runCommand "eval-${name}-generated-noctalia-settings" { } ''
    test "${
      if !noctaliaIsGenerated then "1"  # symlinked config — skip
      else if noctaliaTextAttr == expectedNoctaliaSettings then "1"
      else "0"
    }" = "1"
    touch "$out"
  '';

  "eval-${name}-primary-display-capability" = pkgs.runCommand "eval-${name}-primary-display-capability" { } ''
    test "${if cfg.my.capabilities.primaryDisplayName == expectedPrimaryDisplayName then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-generated-noctalia-monitor-count" =
    assert !noctaliaIsGenerated || builtins.length generatedMonitorWidgets == builtins.length hostCfg.displays;
    pkgs.runCommand "eval-${name}-generated-noctalia-monitor-count" { } ''
      test "${
        if !noctaliaIsGenerated then "1"  # symlinked config — skip
        else if builtins.length generatedMonitorWidgets == builtins.length hostCfg.displays then "1"
        else "0"
      }" = "1"
      touch "$out"
    '';

  "eval-${name}-synthetic-noctalia-multi-display" =
    assert builtins.length syntheticMonitorWidgets == 2;
    assert (builtins.elemAt syntheticMonitorWidgets 0).name == "DP-1";
    assert (builtins.elemAt syntheticMonitorWidgets 1).name == "HDMI-A-1";
    assert builtins.length (builtins.elemAt syntheticMonitorWidgets 0).widgets == 2;
    pkgs.runCommand "eval-${name}-synthetic-noctalia-multi-display" { } ''
      test "${toString (builtins.length syntheticMonitorWidgets)}" = "2"
      test "${(builtins.elemAt syntheticMonitorWidgets 0).name}" = "DP-1"
      test "${(builtins.elemAt syntheticMonitorWidgets 1).name}" = "HDMI-A-1"
      test "${if (builtins.length (builtins.elemAt syntheticMonitorWidgets 0).widgets) == 2 then "1" else "0"}" = "1"
      touch "$out"
    '';
}
