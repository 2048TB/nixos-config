{ lib, pkgs, mainUser, ... }:
let
  homeDir = "/Users/${mainUser}";
  packageSelection = import ../packages/darwin.nix { inherit lib pkgs; };
in
{
  imports = [
    ../base
  ];

  warnings = lib.optionals (packageSelection.skippedNames != [ ]) [
    "Darwin skipped unsupported packages: ${lib.concatStringsSep ", " packageSelection.skippedNames}"
  ];

  home = {
    enableNixpkgsReleaseCheck = false;
    username = mainUser;
    homeDirectory = homeDir;
    stateVersion = "25.11";

    sessionPath = [
      "${homeDir}/.local/bin"
      "${homeDir}/.cargo/bin"
    ];

    inherit (packageSelection) packages;
  };

  programs = {
    fzf = {
      enable = true;
      enableZshIntegration = true;
      defaultCommand = "fd --type f --hidden --follow --exclude .git";
      fileWidgetCommand = "fd --type f --hidden --follow --exclude .git";
      changeDirWidgetCommand = "fd --type d --hidden --follow --exclude .git";
      defaultOptions = [
        "--height=40%"
        "--layout=reverse"
        "--border"
      ];
    };

    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      initContent = builtins.readFile ../configs/shell/zshrc;
    };

    vim = {
      enable = true;
      extraConfig = builtins.readFile ../configs/shell/vimrc;
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
