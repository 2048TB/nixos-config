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
  fcitxExecStartText =
    let
      execStart = hmCfg.systemd.user.services.fcitx5.Service.ExecStart or "";
    in
    if builtins.isList execStart then
      lib.concatStringsSep "\n" execStart
    else
      execStart;
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

  "eval-${name}-river-primary-keybindings" = pkgs.runCommand "eval-${name}-river-primary-keybindings" { } ''
    if [ "${hostCfg.desktopProfile}" = "river" ]; then
      test "${if lib.hasInfix "map normal Super Space spawn fuzzel" riverExtraConfig then "1" else "0"}" = "1"
      test "${if lib.hasInfix "map normal Super Return spawn ghostty" riverExtraConfig then "1" else "0"}" = "1"
      test "${if lib.hasInfix "map normal Super Left focus-view left" riverExtraConfig then "1" else "0"}" = "1"
      test "${if lib.hasInfix "map normal Super Right focus-view right" riverExtraConfig then "1" else "0"}" = "1"
      test "${if lib.hasInfix "map normal Super Up focus-view up" riverExtraConfig then "1" else "0"}" = "1"
      test "${if lib.hasInfix "map normal Super Down focus-view down" riverExtraConfig then "1" else "0"}" = "1"
      test "${if lib.hasInfix "map normal Super A spawn \"take-screenshot area\"" riverExtraConfig then "1" else "0"}" = "1"
      test "${if lib.hasInfix "map normal Super Y spawn river-cliphist-menu" riverExtraConfig then "1" else "0"}" = "1"
      test "${if lib.hasInfix "map normal Super S swap left" riverExtraConfig then "1" else "0"}" = "1"
      test "${if lib.hasInfix "map normal Super G swap right" riverExtraConfig then "1" else "0"}" = "1"
      test "${if lib.hasInfix "map normal Super D swap up" riverExtraConfig then "1" else "0"}" = "1"
      test "${if lib.hasInfix "map normal Super F swap down" riverExtraConfig then "1" else "0"}" = "1"
      test "${if lib.hasInfix "map normal Super X zoom" riverExtraConfig then "1" else "0"}" = "1"
      test "${if lib.hasInfix "map normal Super B send-layout-cmd rivercarro \"main-location-cycle left,monocle\"" riverExtraConfig then "1" else "0"}" = "1"
      test "${if lib.hasInfix "map normal Super C send-layout-cmd rivercarro \"main-count -1\"" riverExtraConfig then "1" else "0"}" = "1"
      test "${if lib.hasInfix "map normal Super V send-layout-cmd rivercarro \"main-count +1\"" riverExtraConfig then "1" else "0"}" = "1"
      test "${if lib.hasInfix "map normal Super Z toggle-fullscreen" riverExtraConfig then "1" else "0"}" = "1"
      test "${if lib.hasInfix "map normal Super Q close" riverExtraConfig then "1" else "0"}" = "1"
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

  "eval-${name}-fcitx5-user-service" = pkgs.runCommand "eval-${name}-fcitx5-user-service" { } ''
    if [ "${hostCfg.desktopProfile}" = "river" ]; then
      test "${if hmCfg.systemd.user.services ? fcitx5 then "1" else "0"}" = "1"
      test "${if builtins.elem "graphical-session.target" (hmCfg.systemd.user.services.fcitx5.Install.WantedBy or [ ]) then "1" else "0"}" = "1"
      test "${fcitxExecStartText}" = "/run/current-system/sw/bin/fcitx5 --replace"
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
