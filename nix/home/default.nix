{ config, pkgs, lib, myvars, mainUser, ... }:
let
  # 配置常量
  homeStateVersion = "25.11";
  polkitStopTimeoutSec = 10;
  polkitRestartSec = 1;
  noctaliaRestartSec = 1;

  # 路径常量（减少重复）
  homeDir = config.home.homeDirectory;
  localBinDir = "${homeDir}/.local/bin";
  localShareDir = "${homeDir}/.local/share";

  mkSymlink = config.lib.file.mkOutOfStoreSymlink;
  # 支持环境变量覆盖配置路径，向后兼容 nix/vars/default.nix
  repoRoot =
    let
      envPath = builtins.getEnv "NIXOS_CONFIG_PATH";
      homePath = "${homeDir}/nixos-config";
    in
    if envPath != "" then envPath
    else if builtins.pathExists homePath then homePath
    else if builtins.pathExists myvars.configRoot then myvars.configRoot
    else homePath;
  niriConf = "${repoRoot}/nix/home/configs/niri";
  noctaliaConf = "${repoRoot}/nix/home/configs/noctalia";
  fcitx5Conf = "${repoRoot}/nix/home/configs/fcitx5";
  ghosttyConf = "${repoRoot}/nix/home/configs/ghostty";
  shellConf = "${repoRoot}/nix/home/configs/shell";
  polkitAgent = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
  niriSession = pkgs.writeScript "niri-session" ''
    #!/usr/bin/env bash
    # 尝试结束旧的 niri 会话，再启动新的会话
    if systemctl --user is-active niri.service >/dev/null 2>&1; then
      systemctl --user stop niri.service
    fi
    /run/current-system/sw/bin/niri-session
  '';
  noctaliaEnv = [
    "QT_QPA_PLATFORM=wayland;xcb"
    "QT_QPA_PLATFORMTHEME=qt6ct"
    "QT_AUTO_SCREEN_SCALE_FACTOR=1"
  ];
in
{

  home.username = mainUser;
  home.homeDirectory = "/home/${mainUser}";
  home.stateVersion = homeStateVersion;

  # 允许全局工具安装到可写目录，避免写入 /nix/store
  home.sessionVariables = {
    NPM_CONFIG_PREFIX = "${homeDir}/.npm-global";
    BUN_INSTALL = "${homeDir}/.bun";
    BUN_INSTALL_BIN = "${homeDir}/.bun/bin";
    BUN_INSTALL_GLOBAL_DIR = "${homeDir}/.bun/install/global";
    BUN_INSTALL_CACHE_DIR = "${homeDir}/.bun/install/cache";
    UV_TOOL_DIR = "${localShareDir}/uv/tools";
    UV_TOOL_BIN_DIR = localBinDir;
    CARGO_HOME = "${homeDir}/.cargo";
    RUSTUP_HOME = "${homeDir}/.rustup";
    GOPATH = "${homeDir}/go";
    GOBIN = "${homeDir}/go/bin";
    PYTHONUSERBASE = "${homeDir}/.local";
    PIPX_HOME = "${localShareDir}/pipx";
    PIPX_BIN_DIR = localBinDir;
    GEM_HOME = "${localShareDir}/gem";
    GEM_PATH = "${localShareDir}/gem";
  };

  home.sessionPath = [
    "${homeDir}/.npm-global/bin"
    "${homeDir}/tools"
    "${homeDir}/.bun/bin"
    "${homeDir}/.cargo/bin"
    "${homeDir}/go/bin"
    "${localShareDir}/gem/bin"
    localBinDir
  ];


  programs.ghostty = {
    enable = true;
    package = pkgs.ghostty;
    enableBashIntegration = false;
    enableZshIntegration = true;
    installBatSyntax = false;
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.swaylock.enable = true;
  programs.wlogout.enable = true;

  programs.mpv = {
    enable = true;
    defaultProfiles = [ "gpu-hq" ];
    scripts = [ pkgs.mpvScripts.mpris ];
  };

  services.playerctld.enable = true;

  home.packages = with pkgs; [
    # === 终端复用器 ===
    tmux # 终端复用器（会话保持、多窗格）
    zellij # 现代化终端复用器（Rust）

    # === 文件管理 ===
    yazi # 终端文件管理器
    bat # cat 增强版（语法高亮）
    fd # find 增强版（更快、更友好）
    eza # ls 增强版（彩色、树状图）
    ripgrep # grep 增强版（递归搜索）
    ripgrep-all # rg 扩展：搜索 PDF/Office 等

    # === 系统监控 ===
    btop # 系统资源监控（CPU、内存、进程）
    duf # 磁盘使用查看（替代 df）
    fastfetch # 系统信息展示

    # === 文本处理 ===
    jq # JSON 处理器（查询、格式化）
    sd # 查找替换（替代 sed）

    # === 网络工具 ===
    curl # HTTP 请求工具
    wget # 文件下载工具

    # === 基础工具 ===
    git # 版本控制
    gh # GitHub CLI
    gnumake # 构建工具
    gcc
    cmake
    ninja
    pkg-config
    binutils
    autoconf
    gettext
    libtool
    automake
    ccache
    clang
    lld
    meson
    gitui # Git TUI (Rust)
    brightnessctl # 屏幕亮度控制
    xdg-utils # XDG 工具集
    xdg-user-dirs # 用户目录管理

    # === Nix 生态工具 ===
    nix-output-monitor # nom - 构建日志美化
    nix-tree # 依赖树可视化
    nix-melt # flake.lock 查看器
    cachix # 二进制缓存管理

    # === 开发效率 ===
    just # 命令运行器（替代 Makefile）

    # === GUI 应用 ===
    google-chrome
    vscode
    remmina
    virt-manager
    virt-viewer
    spice-gtk
    nomacs
    krusader

    # === Wayland 工具 ===
    satty
    swayidle
    mako
    grim
    slurp
    wl-screenrec

    # === 基础 GUI 工具 ===
    kdePackages.ark
    zathura
    gnome-text-editor

    # Ark 格式支持
    p7zip
    unrar
    unar
    arj
    zip
    unzip
    lrzip
    lzop
    zstd

    # === Niri 生态 ===
    vicinae
    noctalia-shell
    swaybg

    # === Wayland 基础设施 ===
    xwayland-satellite
    wl-clipboard
    qt6Packages.qt6ct
    app2unit

    # === Gaming 工具 ===
    gamescope
    mangohud
    umu-launcher
    bbe
    wineWowPackages.stable # 原：stagingFull（避免触发本地编译）
    winetricks
    protonplus

    # Media / graphics
    pavucontrol
    playerctl
    pulsemixer
    imv
    libva-utils
    vdpauinfo
    vulkan-tools
    mesa-demos
    nvitop

    # Virtualisation tools
    qemu_kvm
    mullvad-vpn

    # 通讯软件
    telegram-desktop # 使用官方二进制包（原 nixpaks.telegram-desktop 会触发 30 分钟编译）
  ];

  xdg.configFile = {
    "niri/config.kdl".source = mkSymlink "${repoRoot}/nix/home/configs/niri/config.kdl";
    "niri/keybindings.kdl".source = mkSymlink "${repoRoot}/nix/home/configs/niri/keybindings.kdl";
    "niri/noctalia-shell.kdl".source = mkSymlink "${repoRoot}/nix/home/configs/niri/noctalia-shell.kdl";
    "niri/windowrules.kdl".source = mkSymlink "${repoRoot}/nix/home/configs/niri/windowrules.kdl";
    "niri/niri-hardware.kdl".source = mkSymlink "${repoRoot}/nix/home/configs/niri/niri-hardware.kdl";
    "niri/animation.kdl".source = mkSymlink "${repoRoot}/nix/home/configs/niri/animation.kdl";
    "niri/colors.kdl".source = mkSymlink "${repoRoot}/nix/home/configs/niri/colors.kdl";
    "niri/scripts".source = mkSymlink "${repoRoot}/nix/home/configs/niri/scripts";

    "niriswitcher/config.toml".source = mkSymlink "${repoRoot}/nix/home/configs/niriswitcher/config.toml";
    "niriswitcher/colors.css".source = mkSymlink "${repoRoot}/nix/home/configs/niriswitcher/colors.css";
    "niriswitcher/style.css".source = mkSymlink "${repoRoot}/nix/home/configs/niriswitcher/style.css";

    "noctalia".source = mkSymlink "${noctaliaConf}";
    "qt6ct/qt6ct.conf".source = mkSymlink "${noctaliaConf}/qt6ct.conf";

    "fcitx5/profile" = {
      source = mkSymlink "${fcitx5Conf}/profile";
      force = true;
    };
    "mozc/config1.db".source = mkSymlink "${fcitx5Conf}/mozc-config1.db";

    "ghostty/config".source = mkSymlink "${ghosttyConf}/config";

    "pnpm/rc".text = ''
      global-dir=${localShareDir}/pnpm/global
      global-bin-dir=${localBinDir}
    '';
  };

  xdg.dataFile = {
    "fcitx5/rime/default.custom.yaml".source =
      mkSymlink "${fcitx5Conf}/rime/default.custom.yaml";
  };

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    extraConfig = {
      XDG_SCREENSHOTS_DIR = "$HOME/Pictures/Screenshots";
    };
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "image/jpeg" = [ "org.nomacs.ImageLounge.desktop" "nomacs.desktop" ];
      "image/png" = [ "org.nomacs.ImageLounge.desktop" "nomacs.desktop" ];
      "image/webp" = [ "org.nomacs.ImageLounge.desktop" "nomacs.desktop" ];
      "image/gif" = [ "org.nomacs.ImageLounge.desktop" "nomacs.desktop" ];
      "image/bmp" = [ "org.nomacs.ImageLounge.desktop" "nomacs.desktop" ];
      "image/tiff" = [ "org.nomacs.ImageLounge.desktop" "nomacs.desktop" ];
    };
  };

  home.file = {
    ".wayland-session" = {
      source = niriSession;
      executable = true;
    };
    ".yarnrc".text = ''
      prefix "${homeDir}/.local"
    '';
    ".zshrc".source = mkSymlink "${shellConf}/zshrc";
    ".bashrc".source = mkSymlink "${shellConf}/bashrc";
    ".vimrc".source = mkSymlink "${shellConf}/vimrc";
  };

  systemd.user.services.niri-polkit = {
    Unit = {
      Description = "PolicyKit Authentication Agent (polkit-kde)";
      After = [ "niri.service" ];
      Wants = [ "graphical-session-pre.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = polkitAgent;
      Restart = "on-failure";
      RestartSec = polkitRestartSec;
      TimeoutStopSec = polkitStopTimeoutSec;
    };
    Install.WantedBy = [ "niri.service" ];
  };

  systemd.user.services.noctalia-shell = {
    Unit = {
      Description = "Noctalia Shell - Wayland desktop shell";
      Documentation = "https://docs.noctalia.dev/docs";
      After = [ "niri.service" ];
      PartOf = [ "niri.service" ];
    };

    Service = {
      ExecStart = lib.getExe pkgs.noctalia-shell;
      Restart = "on-failure";
      Environment = noctaliaEnv;
    };

    Install.WantedBy = [ "niri.service" ];
  };
}
