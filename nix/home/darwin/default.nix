{ lib, pkgs, mainUser, myvars, ... }:
let
  homeDir = "/Users/${mainUser}";
  brewPath = "/opt/homebrew/bin:/usr/local/bin";
  sharedNames = [
    "git"
    "gh"
    "tmux"
    "zellij"
    "yazi"
    "bat"
    "fd"
    "eza"
    "ripgrep"
    "jq"
    "wget"
    "just"
  ];

  # Keep package names as strings so missing attrs on Darwin won't break eval.
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

  desiredPackageNames = sharedNames ++ darwinExtraNames;
  resolvePackage =
    name:
    let
      pkgPath = lib.splitString "." name;
      pkg = lib.attrByPath pkgPath null pkgs;
      exists = pkg != null;
      availability =
        if exists
        then builtins.tryEval (lib.meta.availableOn pkgs.stdenv.hostPlatform pkg)
        else {
          success = true;
          value = false;
        };
      available = exists && availability.success && availability.value;
    in
    {
      inherit name pkg available;
    };

  resolved = map resolvePackage desiredPackageNames;
  packageSelection = {
    packages = map (item: item.pkg) (builtins.filter (item: item.available) resolved);
    skippedNames = map (item: item.name) (builtins.filter (item: !item.available) resolved);
  };
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
