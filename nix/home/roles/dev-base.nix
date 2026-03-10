{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    bun
    cargo
    gcc
    gnumake
    go
    nh
    nix-output-monitor
    nvd
    nodejs
    pkg-config
    python3
    rustc
    uv
    zig
  ];

  xdg = {
    enable = true;
    configFile = {
      "ghostty/config".source = ../../../configs/ghostty/config;
      "git/config".source = ../../../configs/git/config;
      "yazi".source = ../../../configs/yazi;
    };
  };

  programs = {
    zsh = {
      enable = true;
      dotDir = config.home.homeDirectory;
      initContent = builtins.readFile ../../../configs/shell/zshrc;
    };
    git.enable = true;
    fzf.enable = true;
    neovim.enable = true;
    tmux = {
      enable = true;
      extraConfig = builtins.readFile ../../../configs/tmux/tmux.conf;
    };
    yazi = {
      enable = true;
      enableZshIntegration = true;
      shellWrapperName = "y";
    };
    zoxide.enable = true;
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
}
