{ lib, pkgs, mainUser, myvars, ... }:
let
  homeDir = "/Users/${mainUser}";
  localBinDir = "${homeDir}/.local/bin";
  localShareDir = "${homeDir}/.local/share";
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
      PYTHONUSERBASE = "${homeDir}/.local";
      PIPX_HOME = "${localShareDir}/pipx";
      PIPX_BIN_DIR = "${localShareDir}/pipx/bin";
    };

    sessionPath = [
      "/opt/homebrew/bin"
      "/usr/local/bin"
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
      envExtra = ''
        export PATH="$PATH:${brewPath}"
      '';
      initContent = builtins.readFile ../configs/shell/zshrc;
    };

    bash = {
      enable = true;
      bashrcExtra = ''
        export PATH="$PATH:${brewPath}"
      '';
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
