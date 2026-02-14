{ config, pkgs, lib, myvars, mainUser, pkgsUnstable ? null, ... }:
let
  # 配置常量
  homeStateVersion = "25.11";

  # 路径常量（减少重复）
  homeDir = config.home.homeDirectory;
  localBinDir = "${homeDir}/.local/bin";
  localShareDir = "${homeDir}/.local/share";

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
  gpuChoice = myvars.gpuMode or "auto";
  ollamaVulkan = pkgs.ollama or null;
  tensorflowCudaPkg = pkgs.python3Packages.tensorflowWithCuda or null;
  tensorflowCudaEnv =
    if tensorflowCudaPkg != null
    then pkgs.python3.withPackages (_: [ tensorflowCudaPkg ])
    else null;
  hashcatPkg = pkgs.hashcat or null;
  hybridPackages =
    lib.optionals (gpuChoice == "amd-nvidia-hybrid" && ollamaVulkan != null) [ ollamaVulkan ]
    ++ lib.optionals (gpuChoice == "amd-nvidia-hybrid" && tensorflowCudaEnv != null) [ tensorflowCudaEnv ]
    ++ lib.optionals (gpuChoice == "amd-nvidia-hybrid" && hashcatPkg != null) [ hashcatPkg ];

  # WPS Office steam-run 包装器
  # 修复 NixOS 上 WPS 无法启动的问题（FHS 兼容性）
  # 参考：https://github.com/NixOS/nixpkgs/issues/125951
  wpsRunWrapper = bin: lib.hiPrio (pkgs.writeShellScriptBin bin ''
    exec steam-run ${pkgs.wpsoffice}/bin/${bin} "$@"
  '');
  wpsWrappedBins = map wpsRunWrapper [ "wps" "et" "wpp" "wpspdf" ];
in
{
  home = {
    username = mainUser;
    homeDirectory = "/home/${mainUser}";
    stateVersion = homeStateVersion;

    # 会话变量（普通 Linux 方案：用户级全局安装目录）
    sessionVariables = {
      # Wayland 支持
      # 关闭 NIXOS_OZONE_WL，避免 VSCode 启动时注入已弃用的 Electron 参数告警
      QT_QPA_PLATFORMTHEME = "qt6ct";

      # 工具链路径
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
      # OpenSSL for Rust openssl-sys on NixOS (user-wide)
      OPENSSL_INCLUDE_DIR = "${pkgs.openssl.dev}/include";
      OPENSSL_LIB_DIR = "${pkgs.openssl.out}/lib";
      OPENSSL_DIR = "${pkgs.openssl.dev}";
    };

    # PATH: 交由 Home Manager 维护，避免手动拼接导致重复/覆盖问题
    sessionPath = [
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

    packages = with pkgs; [
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
      nano # 轻量文本编辑器（用于 Yazi 打开 .txt/.md）
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
      openssl
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
      nil # Nix LSP
      nixpkgs-fmt # Nix 格式化
      statix # Nix linter
      deadnix # 死代码检测

      # === 开发效率 ===
      just # 命令运行器（替代 `Makefile`）
      nix-index # nix-locate 查询工具
      shellcheck # Shell 脚本静态检查
      git-lfs # Git 大文件支持

      # === 图形界面应用 ===
      google-chrome
      vscode
      remmina
      virt-viewer
      spice-gtk
      localsend
      nomacs
      nautilus # GNOME 文件管理器（Wayland 原生，简洁现代）
      file-roller # GNOME 压缩管理器（Nautilus 集成必需）
      ghostty
      cherry-studio # 多 LLM 提供商桌面客户端

      # === Wayland 工具 ===
      satty
      swayidle # 空闲管理（熄屏、休眠），用户自行配置
      grim
      slurp
      wl-screenrec

      # === 基础图形工具 ===
      zathura
      gnome-text-editor
      wpsoffice # WPS Office 办公套件（.desktop 文件和图标由此包提供）

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
      swaybg # 备用壁纸工具（noctalia 主管壁纸，仅做 fallback）

      # === Wayland 基础设施 ===
      cliphist
      wl-clipboard
      xwayland
      qt6Packages.qt6ct
      app2unit
      polkit_gnome # Polkit 认证代理（权限提升对话框，virt-manager/Nautilus 等需要）

      # === 游戏工具 ===
      mangohud
      umu-launcher
      bbe
      wineWowPackages.stable # 原：stagingFull（避免触发本地编译）
      winetricks
      protonplus

      # 媒体 / 图形
      pavucontrol
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
      provider-app-vpn

      # 通讯软件
      telegram-desktop # 使用官方二进制包（原 nixpaks.telegram-desktop 会触发 30 分钟编译）

      # === 语言/包管理补齐 ===
      bun
      pnpm
      pipx
    ]
    ++ hybridPackages
    ++ wpsWrappedBins; # WPS steam-run 包装器（覆盖原始二进制，修复启动问题）

    file = {
      # 便捷入口：保持 /etc/nixos 作为系统入口，同时在主目录提供快速访问路径
      "nixos".source = config.lib.file.mkOutOfStoreSymlink "/persistent/nixos-config";

      ".wayland-session" = {
        source = niriSession;
        executable = true;
      };
      ".cargo/config.toml".text = ''
        [target.x86_64-pc-windows-gnu]
        linker = "x86_64-w64-mingw32-gcc"
        rustflags = [
          "-Lnative=${pkgs.pkgsCross.mingwW64.windows.pthreads}/lib"
        ]
      '';
      ".yarnrc".text = ''
        prefix "${homeDir}/.local"
      '';
    };
  };

  programs = {
    starship = {
      enable = true;
      enableZshIntegration = true;
    };

    zoxide = {
      enable = true;
      enableZshIntegration = true;
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
        "--preview='bat --style=numbers --color=always --line-range=:200 {}'"
      ];
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    # Noctalia Shell 声明式配置（settings/plugins 为 read-only symlink）
    # GUI 修改后需导出回 Nix：noctalia-shell ipc call state all | jq .settings
    noctalia-shell = {
      enable = true;
      settings = builtins.fromJSON (builtins.readFile ./configs/noctalia/settings.json);
      plugins = builtins.fromJSON (builtins.readFile ./configs/noctalia/plugins.json);
      systemd.enable = true;
    };

    # 锁屏与会话菜单由 noctalia 处理（Mod+E / Ctrl+Alt+L）

    mpv = {
      enable = true;
      defaultProfiles = [ "high-quality" ];
      scripts = [ pkgs.mpvScripts.mpris ];
    };

    # 终端 Shell 配置（必需，用于加载会话变量）
    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      envExtra = ''
        export PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig''${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
      '';
      initContent = builtins.readFile ./configs/shell/zshrc;
    };

    bash = {
      enable = true;
    };

    vim = {
      enable = true;
      extraConfig = builtins.readFile ./configs/shell/vimrc;
    };

  };

  services = {
    playerctld.enable = true;

    # USB 设备自动挂载服务
    udiskie = {
      enable = true;
      automount = true;
      notify = true;
      tray = "never"; # Niri 不需要托盘图标
    };
  };

  systemd = {
    user.services =
      {
        # Polkit 认证代理（图形会话自启）
        # 无此服务时，需要权限提升的操作（virt-manager、Nautilus 挂载等）会静默失败
        polkit-gnome-authentication-agent-1 = {
          Unit = {
            Description = "polkit-gnome-authentication-agent-1";
            After = [ "graphical-session.target" ];
          };
          Install.WantedBy = [ "graphical-session.target" ];
          Service = {
            Type = "simple";
            ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
            Restart = "on-failure";
            RestartSec = 1;
            TimeoutStopSec = 10;
          };
        };

        # Clipboard history 依赖（Noctalia 官方示例）
        cliphist-daemon = {
          Unit = {
            Description = "cliphist clipboard history daemon";
            After = [ "graphical-session.target" ];
            PartOf = [ "graphical-session.target" ];
          };
          Install.WantedBy = [ "graphical-session.target" ];
          Service = {
            Type = "simple";
            ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store";
            Restart = "always";
            RestartSec = 2;
          };
        };
      };
  };

  xdg = {
    configFile = {
      # niri 合成器配置（4 个文件）
      "niri/config.kdl".source = ./configs/niri/config.kdl;
      "niri/keybindings.kdl".source = ./configs/niri/keybindings.kdl;
      "niri/windowrules.kdl".source = ./configs/niri/windowrules.kdl;
      "niri/noctalia-shell.kdl".source = ./configs/niri/noctalia-shell.kdl;

      # Noctalia Shell（外壳）配置
      "noctalia/wallpapers".source = ./configs/wallpapers;
      "qt6ct/qt6ct.conf".source = ./configs/noctalia/qt6ct.conf;

      "fcitx5/profile" = {
        source = ./configs/fcitx5/profile;
        force = true;
      };

      "ghostty/config".source = ./configs/ghostty/config;
      "yazi/yazi.toml".source = ./configs/yazi/yazi.toml;
      "yazi/keymap.toml".source = ./configs/yazi/keymap.toml;
      "git/config".source = ./configs/git/config;
      "zellij/config.kdl".source = ./configs/zellij/config.kdl;
      "tmux/tmux.conf".source = ./configs/tmux/tmux.conf;

      "pnpm/rc".text = ''
        global-dir=${localShareDir}/pnpm/global
        global-bin-dir=${localShareDir}/pnpm/bin
      '';
    };

    userDirs = {
      enable = true;
      createDirectories = true;
      extraConfig = {
        XDG_SCREENSHOTS_DIR = "$HOME/Pictures/Screenshots";
      };
    };

    mimeApps = {
      enable = true;
      # 统一图片默认打开方式
      # 使用 genAttrs 保持行为一致，减少重复
      defaultApplications = lib.genAttrs imageMimeTypes (_: imageApps);
    };
  };
}
