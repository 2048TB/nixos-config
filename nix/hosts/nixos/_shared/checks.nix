{ lib
, mylib
, pkgs
, name
, mainUser
, nixosSystem
, expectedLuksName ? "crypted-nixos"
, expectedVideoDrivers ? null
, expectedResumeOffset ? null
, expectedHostProfile ? name
, expectedDockerMode ? null
, expectedTrustedUsers ? [ "root" ]
, expectedTrustedSubstituters ? null
, expectedKvmModules ? null
, derivedCpuVendor ? null
, cpuVendor ? derivedCpuVendor
, ...
}:
let
  cfg = nixosSystem.config;
  hostCfg = cfg.my.host;
  hostRoles = hostCfg.roles or [ ];
  isDesktop = cfg.my.profiles.desktop or false;
  resolvedExpectedVideoDrivers =
    if expectedVideoDrivers != null then
      expectedVideoDrivers
    else if !isDesktop then
      null
    else if hostCfg.gpuMode == "nvidia" then
      [ "nvidia" ]
    else if hostCfg.gpuMode == "amdgpu" then
      [ "amdgpu" ]
    else if hostCfg.gpuMode == "amd-nvidia-hybrid" then
      [ "nvidia" "amdgpu" ]
    else
      [ "modesetting" ];
  resolvedExpectedDockerMode =
    if expectedDockerMode != null then
      expectedDockerMode
    else if builtins.elem "container" hostRoles then
      hostCfg.dockerMode or "rootless"
    else
      "disabled";

  resolvedExpectedKvmModules =
    if expectedKvmModules != null then expectedKvmModules
    else if cpuVendor != null then mylib.kvmModulesForVendor cpuVendor
    else null;
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
    "gnome-keyring"
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
    "xdg-desktop-portal-gtk"
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
  expectsHibernate = expectedResumeOffset != null;
  hasResumeKernelParam =
    builtins.any (param: lib.hasPrefix "resume=" param) cfg.boot.kernelParams;
  hasExpectedResumeKernelParam =
    if expectedResumeKernelParam == null then true else builtins.elem expectedResumeKernelParam cfg.boot.kernelParams;
  hasExpectedResumeKernelParamState =
    if expectsHibernate then hasResumeKernelParam else !hasResumeKernelParam;
  hasExpectedResumeOffsetKernelParamState =
    if expectsHibernate then hasExpectedResumeKernelParam else !(
      builtins.any (param: lib.hasPrefix "resume_offset=" param) cfg.boot.kernelParams
    );
  hasExpectedResumeDeviceState =
    if expectsHibernate then (cfg.boot.resumeDevice or "") != "" else (cfg.boot.resumeDevice or "") == "";
  hasExpectedAcceptFlakeConfig =
    !(cfg.nix.settings.accept-flake-config or false);
  resolvedExpectedTrustedSubstituters =
    if expectedTrustedSubstituters != null then
      expectedTrustedSubstituters
    else
      [
        "https://nix-community.cachix.org"
        "https://nixpkgs-wayland.cachix.org"
        "https://cache.garnix.io"
      ];
  sortedTrustedUsers = builtins.sort builtins.lessThan (cfg.nix.settings.trusted-users or [ ]);
  sortedExpectedTrustedUsers = builtins.sort builtins.lessThan expectedTrustedUsers;
  hasExpectedTrustedUsers = sortedTrustedUsers == sortedExpectedTrustedUsers;
  sortedTrustedSubstituters = builtins.sort builtins.lessThan (cfg.nix.settings.trusted-substituters or [ ]);
  sortedExpectedTrustedSubstituters =
    if resolvedExpectedTrustedSubstituters == null then [ ]
    else builtins.sort builtins.lessThan resolvedExpectedTrustedSubstituters;
  hasExpectedTrustedSubstituters =
    if resolvedExpectedTrustedSubstituters == null then true
    else sortedTrustedSubstituters == sortedExpectedTrustedSubstituters;
  actualDockerMode =
    if (cfg.virtualisation.docker.rootless.enable or false)
    then "rootless"
    else if (cfg.virtualisation.docker.enable or false)
    then "rootful"
    else "disabled";
  hasExpectedDockerMode = actualDockerMode == resolvedExpectedDockerMode;
  actualKvmModules = builtins.filter (m: lib.hasPrefix "kvm-" m) cfg.boot.kernelModules;

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
  "eval-${name}-impermanence-flag" = pkgs.runCommand "eval-${name}-impermanence-flag" { } ''
    test "${if cfg.preservation.enable then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-luks-name" = pkgs.runCommand "eval-${name}-luks-name" { } ''
    test "${cfg.my.host.luksName}" = "${expectedLuksName}"
    touch "$out"
  '';

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

  "eval-${name}-accept-flake-config" = pkgs.runCommand "eval-${name}-accept-flake-config" { } ''
    test "${if hasExpectedAcceptFlakeConfig then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-trusted-users" = pkgs.runCommand "eval-${name}-trusted-users" { } ''
    test "${if hasExpectedTrustedUsers then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-trusted-substituters" = pkgs.runCommand "eval-${name}-trusted-substituters" { } ''
    test "${if hasExpectedTrustedSubstituters then "1" else "0"}" = "1"
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

  "eval-${name}-resume-device" = pkgs.runCommand "eval-${name}-resume-device" { } ''
    if [ "${if expectsHibernate then "1" else "0"}" = "1" ]; then
      test "${cfg.boot.resumeDevice or ""}" = "/dev/mapper/${expectedLuksName}"
    else
      test "${cfg.boot.resumeDevice or ""}" = ""
    fi
    test "${if hasExpectedResumeDeviceState then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-resume-kernel-param" = pkgs.runCommand "eval-${name}-resume-kernel-param" { } ''
    test "${if hasExpectedResumeKernelParamState then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-resume-offset-kernel-param" = pkgs.runCommand "eval-${name}-resume-offset-kernel-param" { } ''
    test "${if hasExpectedResumeOffsetKernelParamState then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-swap-device" = pkgs.runCommand "eval-${name}-swap-device" { } ''
    test "${cfg.fileSystems."/swap".device}" = "/dev/mapper/${expectedLuksName}"
    touch "$out"
  '';
}
// lib.optionalAttrs (resolvedExpectedVideoDrivers != null) {
  "eval-${name}-video-drivers" = pkgs.runCommand "eval-${name}-video-drivers" { } ''
    test "${builtins.toJSON cfg.services.xserver.videoDrivers}" = "${builtins.toJSON resolvedExpectedVideoDrivers}"
    touch "$out"
  '';
}
// lib.optionalAttrs true {
  "eval-${name}-docker-mode" = pkgs.runCommand "eval-${name}-docker-mode" { } ''
    test "${if hasExpectedDockerMode then "1" else "0"}" = "1"
    touch "$out"
  '';
}
  // lib.optionalAttrs (resolvedExpectedKvmModules != null) {
  "eval-${name}-kvm-modules" = pkgs.runCommand "eval-${name}-kvm-modules" { } ''
    test "${builtins.toJSON actualKvmModules}" = "${builtins.toJSON resolvedExpectedKvmModules}"
    touch "$out"
  '';
}
