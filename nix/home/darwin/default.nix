{ lib, pkgs, mylib, mainUser, myvars, osConfig ? null, ... }:
let
  hostCfg = import ../base/resolve-host.nix { inherit myvars osConfig; };
  configFiles = import ../base/config-files.nix;
  homeDir = "/Users/${mainUser}";
  brewPath = "/opt/homebrew/bin:/usr/local/bin";

  darwinExtraNames = [
    "neovim"

    # CLI tools
    "gitui"
    "delta"
    "tealdeer"
    "duf"
    "dust"
    "procs"
  ];

  desiredPackageNames = mylib.sharedPackageNames ++ darwinExtraNames;
  packageSelection = mylib.resolvePackagesByName pkgs desiredPackageNames;
  sourceConfigFiles =
    lib.mapAttrs (_: source: { inherit source; })
      (configFiles.sharedSourceFiles // configFiles.darwinSourceFiles);
in
{
  imports = [
    ../base
  ];

  warnings = lib.optionals (packageSelection.skippedNames != [ ]) [
    "Darwin skipped unsupported packages: ${lib.concatStringsSep ", " packageSelection.skippedNames}"
  ];

  home = {
    enableNixpkgsReleaseCheck = hostCfg.enableHmReleaseCheck or true;
    username = mainUser;
    homeDirectory = homeDir;

    sessionPath = [
      "/opt/homebrew/bin"
      "/usr/local/bin"
    ];

    inherit (packageSelection) packages;
  };

  programs = {
    zsh.envExtra = ''
      export PATH="$PATH:${brewPath}"
    '';

    bash = {
      enable = true;
      bashrcExtra = ''
        export PATH="$PATH:${brewPath}"
      '';
    };
  };

  xdg.configFile = sourceConfigFiles;
}
