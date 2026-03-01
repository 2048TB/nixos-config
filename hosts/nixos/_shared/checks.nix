{ lib
, pkgs
, name
, mainUser
, nixosSystem
, expectedVideoDrivers ? null
, expectedResumeOffset ? null
, expectedHostProfile ? name
, ...
}:
let
  cfg = nixosSystem.config;
  hmCfg = cfg.home-manager.users.${mainUser};
  expectedHome = "/home/${mainUser}";

  getNames = pkgList: lib.unique (map lib.getName pkgList);
  excludeAllowed = allowed: names: builtins.filter (n: !(builtins.elem n allowed)) names;

  allSystemPackageOutPaths = map (pkg: pkg.outPath) cfg.environment.systemPackages;
  systemPackageOutPaths = lib.unique allSystemPackageOutPaths;
  homePackageOutPaths = lib.unique (map (pkg: pkg.outPath) hmCfg.home.packages);
  systemHomeOverlapOutPaths = lib.intersectLists systemPackageOutPaths homePackageOutPaths;
  systemHomeOverlapPkgs =
    lib.filter (pkg: builtins.elem pkg.outPath systemHomeOverlapOutPaths) cfg.environment.systemPackages;
  systemHomeOverlapNames = getNames systemHomeOverlapPkgs;
  systemPackageNames = getNames cfg.environment.systemPackages;
  homePackageNames = getNames hmCfg.home.packages;
  unexpectedOverlapByName = lib.intersectLists systemPackageNames homePackageNames;
  systemDuplicateOutPaths =
    lib.unique (
      builtins.filter
        (outPath: (builtins.length (builtins.filter (p: p == outPath) allSystemPackageOutPaths)) > 1)
        allSystemPackageOutPaths
    );
  systemDuplicatePkgs =
    lib.filter
      (pkg: builtins.elem pkg.outPath systemDuplicateOutPaths)
      cfg.environment.systemPackages;
  systemDuplicateNames = getNames systemDuplicatePkgs;
  allowedSystemDuplicateNames = [
    "dosfstools"
    "fuse"
    "niri"
    "iptables"
    "less"
    "shadow"
    "zsh"
  ];
  unexpectedSystemDuplicateNames = excludeAllowed allowedSystemDuplicateNames systemDuplicateNames;
  allowedSystemHomeOverlapNames = [
    "xwayland"
    "xdg-desktop-portal"
    "xdg-desktop-portal-gnome"
    "python3"
    "zsh"
    "nix-zsh-completions"
    "man-db"
    "shared-mime-info"
  ];
  unexpectedSystemHomeOverlapNames = excludeAllowed allowedSystemHomeOverlapNames systemHomeOverlapNames;
  unexpectedOverlapByNameFiltered = excludeAllowed allowedSystemHomeOverlapNames unexpectedOverlapByName;

  expectedResumeKernelParam =
    if expectedResumeOffset == null then null else "resume_offset=${toString expectedResumeOffset}";
  hasExpectedResumeKernelParam =
    if expectedResumeKernelParam == null then true else builtins.elem expectedResumeKernelParam cfg.boot.kernelParams;
  hasProvider appVpn = cfg.services.provider-app-vpn.enable or false;
  provider-appExecStartPre = cfg.systemd.services.provider-app-daemon.serviceConfig.ExecStartPre or null;
  provider-appExecStartPrePath = if provider-appExecStartPre == null then "" else toString provider-appExecStartPre;

  mkNonEmptyCheck = name': items: msg:
    pkgs.runCommand name' { } ''
      if [ ${toString (builtins.length items)} -ne 0 ]; then
        echo "${msg}: ${lib.concatStringsSep ", " items}" >&2
        exit 1
      fi
      touch "$out"
    '';
in
{
  "eval-${name}-hostname" = pkgs.runCommand "eval-${name}-hostname" { } ''
    test "${cfg.networking.hostName}" = "${name}"
    touch "$out"
  '';

  "eval-${name}-home-directory" = pkgs.runCommand "eval-${name}-home-directory" { } ''
    test "${hmCfg.home.homeDirectory}" = "${expectedHome}"
    touch "$out"
  '';

  "eval-${name}-host-profile" = pkgs.runCommand "eval-${name}-host-profile" { } ''
    test "${hmCfg.home.sessionVariables.HOST_PROFILE or ""}" = "${expectedHostProfile}"
    touch "$out"
  '';

  "eval-${name}-provider-app-prestart-script" = pkgs.runCommand "eval-${name}-provider-app-prestart-script" { } ''
    if [ "${if hasProvider appVpn then "1" else "0"}" != "1" ]; then
      touch "$out"
      exit 0
    fi

    script_path="${provider-appExecStartPrePath}"
    test -n "$script_path"
    test -f "$script_path"

    grep -F 'settings_dir="/etc/provider-app-vpn"' "$script_path" >/dev/null
    grep -F 'settings_file="$settings_dir/settings.json"' "$script_path" >/dev/null
    touch "$out"
  '';

  "eval-${name}-system-home-package-overlap" = mkNonEmptyCheck
    "eval-${name}-system-home-package-overlap"
    unexpectedSystemHomeOverlapNames
    "Unexpected system/home package overlaps";

  "eval-${name}-system-home-package-overlap-by-name" = mkNonEmptyCheck
    "eval-${name}-system-home-package-overlap-by-name"
    unexpectedOverlapByNameFiltered
    "Unexpected system/home package overlaps by name";

  "eval-${name}-system-package-duplicates" = mkNonEmptyCheck
    "eval-${name}-system-package-duplicates"
    unexpectedSystemDuplicateNames
    "Unexpected duplicate packages in environment.systemPackages";
}
// lib.optionalAttrs (expectedVideoDrivers != null) {
  "eval-${name}-video-drivers" = pkgs.runCommand "eval-${name}-video-drivers" { } ''
    test "${builtins.toJSON cfg.services.xserver.videoDrivers}" = "${builtins.toJSON expectedVideoDrivers}"
    touch "$out"
  '';
}
  // lib.optionalAttrs (expectedResumeKernelParam != null) {
  "eval-${name}-resume-offset-kernel-param" = pkgs.runCommand "eval-${name}-resume-offset-kernel-param" { } ''
    test "${if hasExpectedResumeKernelParam then "1" else "0"}" = "1"
    touch "$out"
  '';
}
