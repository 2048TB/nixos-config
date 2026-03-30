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
  resolvedPrimaryDisplay = mylib.primaryDisplay hostCfg;
  expectedPrimaryDisplayName =
    if resolvedPrimaryDisplay == null then null else (resolvedPrimaryDisplay.name or null);
  portalExtraPortalNames =
    map
      (
        pkg:
        if builtins.isString pkg then
          pkg
        else
          (if pkg ? pname then pkg.pname else lib.getName pkg)
      )
      (hmCfg.xdg.portal.extraPortals or [ ]);
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
      test "${if hmCfg.systemd.user.services ? fcitx5 then "1" else "0"}" = "1"
    fi
    touch "$out"
  '';

  "eval-${name}-river-portal-wlr-backends" = pkgs.runCommand "eval-${name}-river-portal-wlr-backends" { } ''
    if [ "${hostCfg.desktopProfile}" = "river" ]; then
      test "${if builtins.elem "xdg-desktop-portal-wlr" portalExtraPortalNames then "1" else "0"}" = "1"
      test "${hmCfg.xdg.portal.config.river."org.freedesktop.impl.portal.Screenshot" or ""}" = "wlr"
      test "${hmCfg.xdg.portal.config.river."org.freedesktop.impl.portal.ScreenCast" or ""}" = "wlr"
    fi
    touch "$out"
  '';
}
