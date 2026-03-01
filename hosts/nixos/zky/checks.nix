{ lib
, pkgs
, name
, mainUser
, nixosSystem
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
