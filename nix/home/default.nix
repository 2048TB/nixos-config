{ config, pkgs, lib, myvars, mainUser, ... }:
let
  # 配置常量
  homeStateVersion = "25.11";

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
    if envPath != "" && builtins.pathExists envPath then envPath
    else if builtins.pathExists myvars.configRoot then myvars.configRoot
    else if builtins.pathExists homePath then homePath
    else homePath;
  configsRoot = "${repoRoot}/nix/home/configs";
  noctaliaConf = "${configsRoot}/noctalia";
  fcitx5Conf = "${configsRoot}/fcitx5";
  ghosttyConf = "${configsRoot}/ghostty";
  niriConf = "${configsRoot}/niri";
  imageMimeTypes = [
    "image/jpeg"
    "image/png"
    "image/webp"
    "image/gif"
    "image/bmp"
    "image/tiff"
  ];
  imageApps = [ "org.nomacs.ImageLounge.desktop" "nomacs.desktop" ];
  niriSession = pkgs.writeScript "niri-session" ''
    #!/usr/bin/env bash
    # 尝试结束旧的 niri 会话，避免残留服务状态影响新会话
    if systemctl --user is-active niri.service >/dev/null 2>&1; then
      systemctl --user stop niri.service
    fi
    /run/current-system/sw/bin/niri-session
  '';

  # 仅在混合显卡（amd-nvidia-hybrid）时安装 GPU 加速相关软件
  gpuChoice =
    let
      envGpu = builtins.getEnv "NIXOS_GPU";
      gpuFile = "${repoRoot}/nix/vars/detected-gpu.txt";
      raw =
        if envGpu != "" then envGpu
        else if builtins.pathExists gpuFile then builtins.readFile gpuFile
        else "auto";
    in
    lib.strings.removeSuffix "\n" (lib.strings.removeSuffix "\r" raw);
  ollamaVulkan = if pkgs ? "ollama-vulkan" then pkgs."ollama-vulkan" else null;
  tensorflowCudaEnv =
    if pkgs.python3Packages ? tensorflowWithCuda
    then pkgs.python3.withPackages (ps: [ ps.tensorflowWithCuda ])
    else null;
  hashcatPkg = if pkgs ? hashcat then pkgs.hashcat else null;
  hybridPackages =
    lib.optionals (gpuChoice == "amd-nvidia-hybrid" && ollamaVulkan != null) [ ollamaVulkan ]
    ++ lib.optionals (gpuChoice == "amd-nvidia-hybrid" && tensorflowCudaEnv != null) [ tensorflowCudaEnv ]
    ++ lib.optionals (gpuChoice == "amd-nvidia-hybrid" && hashcatPkg != null) [ hashcatPkg ];
in
{

  home.username = mainUser;
  home.homeDirectory = "/home/${mainUser}";
  home.stateVersion = homeStateVersion;

  # 允许全局工具安装到可写目录，避免写入 /nix/store
  home.sessionVariables = {
    # Wayland 支持
    NIXOS_OZONE_WL = "1"; # Electron 应用（Chrome、VSCode）在 Wayland 下原生支持

    # 工具链路径
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

  # 保留手动锁屏功能（关闭自动锁屏）
  programs.swaylock.enable = true;
  programs.wlogout.enable = true;

  programs.mpv = {
    enable = true;
    defaultProfiles = [ "gpu-hq" ];
    scripts = [ pkgs.mpvScripts.mpris ];
  };

  # 终端 Shell 配置（必需，用于加载会话变量）
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    initContent = builtins.readFile ./configs/shell/zshrc;
  };

  programs.bash = {
    enable = true;
    initExtra = builtins.readFile ./configs/shell/bashrc;
  };

  programs.vim = {
    enable = true;
    extraConfig = builtins.readFile ./configs/shell/vimrc;
  };

  services.playerctld.enable = true;

  # USB 设备自动挂载服务
  services.udiskie = {
    enable = true;
    automount = true;
    notify = true;
    tray = "never"; # Niri 不需要托盘图标
  };

  home.packages = with pkgs; [
    # === 终端复用器 ===
    tmux # 终端复用器（会话保持、多窗格）
    zellij # 现代化终端复用器（Rust）

    # === 文件管理 ===
    yazi # 终端文件管理器
    bat # `cat` 增强版（语法高亮）
    fd # `find` 增强版（更快、更友好）
    eza # `ls` 增强版（彩色、树状图）
    ripgrep # `grep` 增强版（递归搜索）
    ripgrep-all # rg 扩展：搜索 PDF/Office 等

    # === 系统监控 ===
    btop # 系统资源监控（CPU、内存、进程）
    duf # 磁盘使用查看（替代 `df`）
    dust # 磁盘空间树状图（替代 `du`，可视化目录大小）
    procs # 进程查看（替代 `ps`，彩色表格化）
    fastfetch # 系统信息展示

    # === 文本处理 ===
    jq # JSON 处理器（查询、格式化）
    sd # 查找替换（替代 `sed`）
    tealdeer # 命令示例（`tldr`，简化版 `man` 页面）

    # === 网络工具 ===
    curl # HTTP 请求工具
    wget # 文件下载工具

    # === 基础工具 ===
    git # 版本控制
    gh # GitHub 命令行工具
    gnumake # 构建工具
    cmake
    ninja
    pkg-config
    autoconf
    gettext
    libtool
    automake
    ccache
    clang
    meson
    gitui # Git TUI（Rust）
    delta # git diff 美化（语法高亮、并排对比）
    tokei # 代码统计（行数、语言分布）
    brightnessctl # 屏幕亮度控制
    xdg-utils # XDG 工具集
    xdg-user-dirs # 用户目录管理

    # === Nix 生态工具 ===
    nix-output-monitor # nom - 构建日志美化
    nix-tree # 依赖树可视化
    nix-melt # flake.lock 查看器
    cachix # 二进制缓存管理

    # === 开发效率 ===
    just # 命令运行器（替代 `Makefile`）

    # === 图形界面应用 ===
    google-chrome
    vscode
    remmina
    virt-viewer
    spice-gtk
    nomacs
    nautilus # GNOME 文件管理器（Wayland 原生，简洁现代）
    file-roller # GNOME 压缩管理器（Nautilus 集成必需）
    cherry-studio # 多 LLM 提供商桌面客户端

    # === Wayland 工具 ===
    satty
    swayidle # 空闲管理（熄屏、休眠），用户自行配置
    mako
    grim
    slurp
    wl-screenrec

    # === 基础图形工具 ===
    zathura
    gnome-text-editor
    wpsoffice # WPS Office 办公套件（文档/表格/演示）

    # 压缩/解压工具（命令行 + Nautilus file-roller 集成）
    p7zip-rar # 包含 7-Zip + RAR 支持（非自由许可）
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
    wl-clipboard
    qt6Packages.qt6ct
    app2unit

    # === 游戏工具 ===
    mangohud
    umu-launcher
    bbe
    wineWowPackages.stable # 原：stagingFull（避免触发本地编译）
    winetricks
    protonplus

    # 媒体 / 图形
    pavucontrol
    playerctl
    pulsemixer
    splayer # 网易云音乐播放器（支持本地音乐、流媒体、逐字歌词）
    imv
    libva-utils
    vdpauinfo
    vulkan-tools
    mesa-demos
    nvitop

    # 虚拟化工具
    qemu_kvm
    docker-compose # Docker 编排工具
    dive # Docker 镜像分析
    lazydocker # Docker TUI 管理器
    mullvad-vpn

    # 通讯软件
    telegram-desktop # 使用官方二进制包（原 nixpaks.telegram-desktop 会触发 30 分钟编译）
  ] ++ hybridPackages;

  # Niri 配置：使用手动 KDL 文件而非声明式配置
  programs.niri.config = null; # 阻止自动生成，使用下方的手动配置文件

  xdg.configFile = {
    # niri 合成器配置（4 个文件）
    "niri/config.kdl".source = mkSymlink "${niriConf}/config.kdl";
    "niri/keybindings.kdl".source = mkSymlink "${niriConf}/keybindings.kdl";
    "niri/windowrules.kdl".source = mkSymlink "${niriConf}/windowrules.kdl";
    "niri/noctalia-shell.kdl".source = mkSymlink "${niriConf}/noctalia-shell.kdl";

    # Noctalia Shell（外壳）配置（分别链接文件以支持壁纸子目录）
    "noctalia/settings.json".source = mkSymlink "${noctaliaConf}/settings.json";
    "noctalia/plugins.json".source = mkSymlink "${noctaliaConf}/plugins.json";
    "noctalia/wallpapers".source = mkSymlink "${configsRoot}/wallpapers";
    "qt6ct/qt6ct.conf".source = mkSymlink "${noctaliaConf}/qt6ct.conf";

    "fcitx5/profile" = {
      source = mkSymlink "${fcitx5Conf}/profile";
      force = true;
    };

    "ghostty/config".source = mkSymlink "${ghosttyConf}/config";

    "pnpm/rc".text = ''
      global-dir=${localShareDir}/pnpm/global
      global-bin-dir=${localBinDir}
    '';
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
    # 统一图片默认打开方式
    # 使用 genAttrs 保持行为一致，减少重复
    defaultApplications = lib.genAttrs imageMimeTypes (_: imageApps);
  };

  home.file = {
    ".wayland-session" = {
      source = niriSession;
      executable = true;
    };
    ".cache/noctalia/wallpapers.json".text = builtins.toJSON {
      defaultWallpaper = "${homeDir}/.config/noctalia/wallpapers/1.png";
      wallpapers = { };
    };
    ".yarnrc".text = ''
      prefix "${homeDir}/.local"
    '';
  };
}
