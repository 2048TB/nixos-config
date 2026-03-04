{ config, myvars, ... }:
let
  homeDir = config.home.homeDirectory;
  localShareDir = "${homeDir}/.local/share";
  localBinDir = "${homeDir}/.local/bin";
in
{
  programs = {
    starship = {
      enable = true;
      enableZshIntegration = true;
    };

    zoxide = {
      enable = true;
      enableZshIntegration = true;
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

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

  home.sessionVariables = {
    HOST_PROFILE = myvars.hostname;
    NPM_CONFIG_PREFIX = "${homeDir}/.npm-global";
    BUN_INSTALL = "${homeDir}/.bun";
    BUN_INSTALL_BIN = "${homeDir}/.bun/bin";
    BUN_INSTALL_GLOBAL_DIR = "${homeDir}/.bun/install/global";
    BUN_INSTALL_CACHE_DIR = "${homeDir}/.bun/install/cache";
    UV_TOOL_DIR = "${localShareDir}/uv/tools";
    UV_TOOL_BIN_DIR = "${localShareDir}/uv/bin";
    UV_PYTHON_DOWNLOADS = "never";
    CARGO_HOME = "${homeDir}/.cargo";
    GOPATH = "${homeDir}/go";
    GOBIN = "${homeDir}/go/bin";
    PIPX_HOME = "${localShareDir}/pipx";
    PIPX_BIN_DIR = "${localShareDir}/pipx/bin";
  };

  home.sessionPath = [
    "${homeDir}/.npm-global/bin"
    "${homeDir}/tools"
    "${homeDir}/.bun/bin"
    "${homeDir}/.cargo/bin"
    "${homeDir}/go/bin"
    "${localShareDir}/pnpm/bin"
    "${localShareDir}/pipx/bin"
    "${localShareDir}/uv/bin"
    localBinDir
  ];
}
