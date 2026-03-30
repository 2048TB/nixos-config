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
  "eval-${name}-primary-display-capability" = pkgs.runCommand "eval-${name}-primary-display-capability" { } ''
    test "${if cfg.my.capabilities.primaryDisplayName == expectedPrimaryDisplayName then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-river-hm-systemd-enabled" = pkgs.runCommand "eval-${name}-river-hm-systemd-enabled" { } ''
    if [ "${hostCfg.desktopProfile}" = "river" ]; then
      test "${if (hmCfg.wayland.windowManager.river.systemd.enable or false) then "1" else "0"}" = "1"
    fi
    touch "$out"
  '';

  "eval-${name}-fcitx5-user-service" = pkgs.runCommand "eval-${name}-fcitx5-user-service" { } ''
    if [ "${hostCfg.desktopProfile}" = "river" ]; then
      test "${if hmCfg.systemd.user.services ? fcitx5-daemon then "1" else "0"}" = "1"
    fi
    touch "$out"
  '';

  # xdg-desktop-portal-wlr 由 NixOS programs.river-classic 系统级提供，HM 侧只检查 portal config 映射
  "eval-${name}-river-portal-wlr-backends" = pkgs.runCommand "eval-${name}-river-portal-wlr-backends" { } ''
    if [ "${hostCfg.desktopProfile}" = "river" ]; then
      test "${hmCfg.xdg.portal.config.river."org.freedesktop.impl.portal.Screenshot" or ""}" = "wlr"
      test "${hmCfg.xdg.portal.config.river."org.freedesktop.impl.portal.ScreenCast" or ""}" = "wlr"
    fi
    touch "$out"
  '';
}
