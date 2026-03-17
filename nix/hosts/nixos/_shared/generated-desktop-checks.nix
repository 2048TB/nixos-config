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
  expectedUserBin = "/etc/profiles/per-user/${mainUser}/bin";
  riverExtraConfig = hmCfg.wayland.windowManager.river.extraConfig or "";
  waybarConfigText = hmCfg.xdg.configFile."waybar/config".text or "";
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

  "eval-${name}-river-hm-xwayland-disabled" = pkgs.runCommand "eval-${name}-river-hm-xwayland-disabled" { } ''
    if [ "${hostCfg.desktopProfile}" = "river" ]; then
      test "${if (hmCfg.wayland.windowManager.river.xwayland.enable or true) then "1" else "0"}" = "0"
    fi
    touch "$out"
  '';

  "eval-${name}-river-hm-systemd-enabled" = pkgs.runCommand "eval-${name}-river-hm-systemd-enabled" { } ''
    if [ "${hostCfg.desktopProfile}" = "river" ]; then
      test "${if (hmCfg.wayland.windowManager.river.systemd.enable or false) then "1" else "0"}" = "1"
    fi
    touch "$out"
  '';

  "eval-${name}-river-manual-lock-binding" = pkgs.runCommand "eval-${name}-river-manual-lock-binding" { } ''
    if [ "${hostCfg.desktopProfile}" = "river" ]; then
      test "${if lib.hasInfix "map normal Super+Shift X spawn lock-screen" riverExtraConfig then "1" else "0"}" = "1"
    fi
    touch "$out"
  '';

  "eval-${name}-waybar-swaync-client-hooks" = pkgs.runCommand "eval-${name}-waybar-swaync-client-hooks" { } ''
    if [ "${hostCfg.desktopProfile}" = "river" ]; then
      test "${if lib.hasInfix "${expectedUserBin}/swaync-client -swb" waybarConfigText then "1" else "0"}" = "1"
      test "${if lib.hasInfix "${expectedUserBin}/swaync-client -t -sw" waybarConfigText then "1" else "0"}" = "1"
      test "${if lib.hasInfix "${expectedUserBin}/swaync-client -d -sw" waybarConfigText then "1" else "0"}" = "1"
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
