{ lib, pkgs, mylib, mainUser, myvars, ... }:
let
  homeDir = "/Users/${mainUser}";
  brewPath = "/opt/homebrew/bin:/usr/local/bin";

  darwinExtraNames = [
    # Programming languages and toolchains
    "go"
    "rustup"
    "nodejs_22"
    "python3"
    "bun"
    "pnpm"
    "pipx"
    "zig"

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
in
{
  imports = [
    ../base
  ];

  warnings = lib.optionals (packageSelection.skippedNames != [ ]) [
    "Darwin skipped unsupported packages: ${lib.concatStringsSep ", " packageSelection.skippedNames}"
  ];

  home = {
    enableNixpkgsReleaseCheck = myvars.enableHmReleaseCheck or true;
    username = mainUser;
    homeDirectory = homeDir;
    stateVersion = myvars.homeStateVersion or "25.11";

    sessionVariables = {
      PYTHONUSERBASE = "${homeDir}/.local";
    };

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

  xdg.configFile = {
    "git/config".source = ../configs/git/config;
    "ghostty/config".source = ../configs/ghostty/config;
    "tmux/tmux.conf".source = ../configs/tmux/tmux.conf;
    "zellij/config.kdl".source = ../configs/zellij/config.kdl;
    "yazi/yazi.toml".source = ../configs/yazi/yazi.toml;
    "yazi/keymap.toml".source = ../configs/yazi/keymap.toml;
  };
}
