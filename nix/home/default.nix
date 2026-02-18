{ config, pkgs, lib, myvars, mainUser, ... }:
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
  riverSessionBootstrap = pkgs.writeShellScript "river-session-bootstrap" ''
    # 等待输出初始化完成后统一设置缩放，避免字体过小
    sleep 1
    for out in $(${pkgs.wlr-randr}/bin/wlr-randr | ${pkgs.gawk}/bin/awk '/^[^[:space:]]/ { print $1 }'); do
      ${pkgs.wlr-randr}/bin/wlr-randr --output "$out" --scale 1.20 || true
    done
  '';
  waylandSession = pkgs.writeScript "wayland-session" ''
    #!/usr/bin/env bash
    hm_vars="/etc/profiles/per-user/${mainUser}/etc/profile.d/hm-session-vars.sh"
    if [ -f "$hm_vars" ]; then
      # shellcheck disable=SC1090
      . "$hm_vars"
    fi

    # 由 Home Manager 的 wayland.windowManager.river.systemd.enable
    # 统一导入关键环境变量到 systemd user / dbus，避免重复导入。

    # 尝试结束旧的 river 会话，避免残留服务状态影响新会话
    if systemctl --user is-active river-session.target >/dev/null 2>&1; then
      systemctl --user stop river-session.target
    fi
    exec /run/current-system/sw/bin/river
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
  # 统一 Wlogout 调用入口，避免 Waybar/Niri 参数漂移
  wlogoutMenu = pkgs.writeShellScriptBin "wlogout-menu" ''
    exec ${pkgs.wlogout}/bin/wlogout \
      --protocol layer-shell \
      --no-span \
      --buttons-per-row 3 \
      --column-spacing 18 \
      --row-spacing 18 \
      -l "${homeDir}/.config/wlogout/layout" \
      -C "${homeDir}/.config/wlogout/style.css" \
      "$@"
  '';
  riverScreenshot = pkgs.writeShellScriptBin "river-screenshot" ''
    set -euo pipefail
    mode="''${1:-full}"
    dir="''${XDG_SCREENSHOTS_DIR:-$HOME/Pictures/Screenshots}"
    mkdir -p "$dir"
    path="$dir/Screenshot from $(date '+%Y-%m-%d %H-%M-%S').png"

    case "$mode" in
      full)
        ${pkgs.grim}/bin/grim - | tee "$path" | ${pkgs.wl-clipboard}/bin/wl-copy --type image/png
        ;;
      area)
        region="$(${pkgs.slurp}/bin/slurp)" || exit 0
        [ -n "$region" ] || exit 0
        ${pkgs.grim}/bin/grim -g "$region" - | tee "$path" | ${pkgs.wl-clipboard}/bin/wl-copy --type image/png
        ;;
      *)
        exit 1
        ;;
    esac
  '';
  riverCliphistMenu = pkgs.writeShellScriptBin "river-cliphist-menu" ''
    set -euo pipefail
    picked="$(${pkgs.cliphist}/bin/cliphist list | ${pkgs.fuzzel}/bin/fuzzel --dmenu || true)"
    [ -n "$picked" ] || exit 0
    printf '%s' "$picked" | ${pkgs.cliphist}/bin/cliphist decode | ${pkgs.wl-clipboard}/bin/wl-copy
  '';
  swayncSettings = {
    "$schema" = "/etc/xdg/swaync/configSchema.json";
    positionX = "right";
    positionY = "top";
    layer = "overlay";
    "control-center-layer" = "top";
    "layer-shell" = true;
    "control-center-margin-top" = 10;
    "control-center-margin-bottom" = 10;
    "control-center-margin-right" = 10;
    "control-center-margin-left" = 10;
    "notification-2fa-action" = true;
    "notification-inline-replies" = false;
    "notification-body-image-height" = 100;
    "notification-body-image-width" = 200;
    timeout = 10;
    "timeout-low" = 5;
    "timeout-critical" = 0;
    "fit-to-screen" = true;
    "relative-timestamps" = true;
    "control-center-width" = 500;
    "control-center-height" = 900;
    "notification-window-width" = 450;
    "keyboard-shortcuts" = true;
    "notification-grouping" = true;
    "image-visibility" = "when-available";
    "transition-time" = 200;
    "hide-on-clear" = false;
    "hide-on-action" = true;
    "text-empty" = "No Notifications";
    widgets = [
      "title"
      "dnd"
      "notifications"
      "mpris"
    ];
    "widget-config" = {
      title = {
        text = "Notification Center";
        "clear-all-button" = true;
        "button-text" = "Clear";
      };
      dnd = {
        text = "Do Not Disturb";
      };
      label = {
        "max-lines" = 1;
        text = "Notification Center";
      };
      mpris = {
        "image-size" = 80;
        "image-radius" = 8;
      };
    };
  };
  swayncStyle = ''
    * {
      font-family: "Maple Mono NF CN", "Sarasa UI SC", "JetBrainsMono Nerd Font", sans-serif;
      font-size: 13px;
    }

    .control-center {
      background: #1e1e2e;
      border: 1px solid rgba(255, 255, 255, 0.12);
      border-radius: 14px;
    }

    .control-center .widget-title,
    .control-center .widget-dnd,
    .control-center .widget-mpris {
      background: rgba(255, 255, 255, 0.03);
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: 10px;
      margin: 8px 10px 0 10px;
      padding: 8px 10px;
    }

    .control-center .widget-title > button {
      background: #89b4fa;
      color: #1e1e2e;
      border-radius: 8px;
      border: none;
      padding: 4px 10px;
    }

    .notification-row:focus,
    .notification-row:hover {
      background: transparent;
    }

    .notification {
      background: #1e1e2e;
      border: 1px solid rgba(255, 255, 255, 0.08);
      border-radius: 12px;
      margin: 6px 10px;
      padding: 0;
    }

    .notification-content {
      padding: 8px 10px;
    }

    .notification-default-action:hover,
    .notification-action:hover {
      background: rgba(137, 180, 250, 0.18);
    }

    .notification.critical {
      border-color: rgba(243, 139, 168, 0.45);
    }

    .widget-dnd > switch {
      background: #313244;
      border-radius: 999px;
    }

    .widget-dnd > switch:checked {
      background: #89b4fa;
    }

    .widget-dnd > switch slider {
      background: #cdd6f4;
      border-radius: 999px;
    }
  '';
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
      # 输入法环境变量（river 会话下显式声明，避免 Fcitx5 未接管）
      INPUT_METHOD = "fcitx";
      GTK_IM_MODULE = "fcitx";
      QT_IM_MODULE = "fcitx";
      XMODIFIERS = "@im=fcitx";
      SDL_IM_MODULE = "fcitx";

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
      jq # JSON 处理器（查询、格式化）
      sd # 查找替换（替代 `sed`）
      tealdeer # 命令示例（`tldr`，简化版 `man` 页面）

      # === 网络工具 ===
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
      foot # 轻量 Wayland 终端（备用）
      cherry-studio # 多 LLM 提供商桌面客户端

      # === Wayland 工具 ===
      satty
      swayidle # 空闲管理（熄屏、休眠），用户自行配置
      grim
      slurp
      wl-screenrec
      wlr-randr # river 下设置输出缩放（修复字体过小）

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

      # === River 生态 ===
      fuzzel
      waybar
      swaylock
      wlogout
      gnome-calculator
      swaybg # 备用壁纸工具（手动/脚本场景可用）

      # === Wayland 基础设施 ===
      cliphist
      wl-clipboard
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
    ++ [
      wlogoutMenu
      riverScreenshot
      riverCliphistMenu
    ]
    ++ wpsWrappedBins; # WPS steam-run 包装器（覆盖原始二进制，修复启动问题）

    file = {
      # 便捷入口：保持 /etc/nixos 作为系统入口，同时在主目录提供快速访问路径
      "nixos".source = config.lib.file.mkOutOfStoreSymlink "/persistent/nixos-config";

      ".wayland-session" = {
        source = waylandSession;
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

    vim = {
      enable = true;
      extraConfig = builtins.readFile ./configs/shell/vimrc;
    };

  };

  wayland.windowManager.river = {
    enable = true;
    package = null; # 由 NixOS 的 programs.river-classic 安装
    systemd.enable = true;
    extraSessionVariables = {
      XDG_CURRENT_DESKTOP = "river";
      XDG_SESSION_DESKTOP = "river";
    };
    extraConfig = ''
      riverctl spawn '${riverSessionBootstrap}'

      riverctl background-color 0x1e1e2e
      riverctl border-width 1
      riverctl border-color-focused 0x4a3f64
      riverctl border-color-unfocused 0x2c2938
      riverctl set-repeat 50 300

      riverctl map normal Super Return spawn ghostty
      riverctl map normal Super Space spawn '/etc/profiles/per-user/${mainUser}/bin/fuzzel'
      riverctl map normal Super D spawn nautilus
      riverctl map normal Super+Control C spawn '/etc/profiles/per-user/${mainUser}/bin/river-cliphist-menu'
      riverctl map normal Super+Control S spawn pavucontrol
      riverctl map normal Super Q close
      riverctl map normal Super+Shift E exit
      riverctl map normal Super+Shift L spawn 'swaylock -f'
      riverctl map normal Super+Control E spawn '/etc/profiles/per-user/${mainUser}/bin/wlogout-menu'

      # 焦点与交换（常用双键）
      riverctl map normal Super Right focus-view -skip-floating next
      riverctl map normal Super Left focus-view -skip-floating previous
      riverctl map normal Super Down swap next
      riverctl map normal Super Up swap previous

      riverctl map normal Super Z zoom
      riverctl map normal Super F toggle-fullscreen
      riverctl map normal Super V toggle-float

      # rivertile 控制（低频三键，不使用标点）
      riverctl map normal Super+Control Up send-layout-cmd rivertile "main-ratio +0.05"
      riverctl map normal Super+Control Down send-layout-cmd rivertile "main-ratio -0.05"
      riverctl map normal Super+Control Right send-layout-cmd rivertile "main-count +1"
      riverctl map normal Super+Control Left send-layout-cmd rivertile "main-count -1"
      riverctl map normal Super+Shift Up send-layout-cmd rivertile "main-location top"
      riverctl map normal Super+Shift Right send-layout-cmd rivertile "main-location right"
      riverctl map normal Super+Shift Down send-layout-cmd rivertile "main-location bottom"
      riverctl map normal Super+Shift Left send-layout-cmd rivertile "main-location left"

      # 浮动窗口模式：Super+G 进入，模式内方向键处理移动/吸附/缩放
      riverctl declare-mode float
      riverctl map normal Super G enter-mode float
      riverctl map float None Escape enter-mode normal
      riverctl map float None Return enter-mode normal
      riverctl map float None Space enter-mode normal
      riverctl map float None V toggle-float
      riverctl map float None Left move left 100
      riverctl map float None Down move down 100
      riverctl map float None Up move up 100
      riverctl map float None Right move right 100
      riverctl map float Shift Left resize horizontal -100
      riverctl map float Shift Down resize vertical 100
      riverctl map float Shift Up resize vertical -100
      riverctl map float Shift Right resize horizontal 100
      riverctl map float Control Left snap left
      riverctl map float Control Down snap down
      riverctl map float Control Up snap up
      riverctl map float Control Right snap right

      riverctl map normal None Print spawn '${riverScreenshot}/bin/river-screenshot area'
      riverctl map normal Super X spawn '${riverScreenshot}/bin/river-screenshot area'

      riverctl map-pointer normal Super BTN_LEFT move-view
      riverctl map-pointer normal Super BTN_RIGHT resize-view
      riverctl map-pointer normal Super BTN_MIDDLE toggle-float

      riverctl declare-mode passthrough
      riverctl map normal Super P enter-mode passthrough
      riverctl map passthrough Super P enter-mode normal
      riverctl map passthrough None Escape enter-mode normal

      for i in $(seq 1 9); do
          tags=$((1 << ($i - 1)))
          riverctl map normal Super $i set-focused-tags $tags
          riverctl map normal Super+Shift $i set-view-tags $tags
          riverctl map normal Super+Alt $i toggle-focused-tags $tags
          riverctl map normal Super+Control $i toggle-view-tags $tags
      done

      all_tags=$(((1 << 32) - 1))
      riverctl map normal Super 0 set-focused-tags $all_tags
      riverctl map normal Super+Shift 0 set-view-tags $all_tags
      riverctl map normal Super Tab focus-previous-tags
      riverctl map normal Super+Shift Tab send-to-previous-tags

      for mode in normal locked; do
          riverctl map $mode None XF86AudioRaiseVolume spawn 'wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.01+ --limit 1.0'
          riverctl map $mode None XF86AudioLowerVolume spawn 'wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.01-'
          riverctl map $mode None XF86AudioMute spawn 'wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle'
          riverctl map $mode None XF86AudioMicMute spawn 'wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle'
          riverctl map $mode None XF86AudioPlay spawn 'playerctl play-pause'
          riverctl map $mode None XF86AudioPrev spawn 'playerctl previous'
          riverctl map $mode None XF86AudioNext spawn 'playerctl next'
          riverctl map $mode None XF86MonBrightnessUp spawn 'brightnessctl --class=backlight set 1%+'
          riverctl map $mode None XF86MonBrightnessDown spawn 'brightnessctl --class=backlight set 1%-'
      done

      riverctl default-layout rivertile
      rivertile -view-padding 8 -outer-padding 8 &
    '';
  };

  services = {
    playerctld.enable = true;

    # USB 设备自动挂载服务
    udiskie = {
      enable = true;
      automount = true;
      notify = true;
      tray = "never"; # Wayland 会话使用 Waybar 托盘模块
    };

    swaync = {
      enable = true;
      settings = swayncSettings;
      style = swayncStyle;
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

        # Clipboard history
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

        waybar = {
          Unit = {
            Description = "Waybar status bar";
            After = [ "graphical-session.target" ];
            PartOf = [ "graphical-session.target" ];
          };
          Install.WantedBy = [ "graphical-session.target" ];
          Service = {
            Type = "simple";
            ExecStart = "${pkgs.waybar}/bin/waybar";
            Restart = "always";
            RestartSec = 2;
          };
        };

        swaybg = {
          Unit = {
            Description = "Wallpaper daemon (swaybg)";
            After = [ "graphical-session.target" ];
            PartOf = [ "graphical-session.target" ];
          };
          Install.WantedBy = [ "graphical-session.target" ];
          Service = {
            Type = "simple";
            ExecStart = "${pkgs.swaybg}/bin/swaybg -i ${homeDir}/.config/wallpapers/default.png -m fill";
            Restart = "on-failure";
            RestartSec = 2;
          };
        };

        # 在 greetd + river 会话中显式拉起输入法，避免仅依赖 XDG autostart 导致未启动
        fcitx5 = {
          Unit = {
            Description = "Fcitx5 input method daemon";
            After = [ "graphical-session.target" ];
            PartOf = [ "graphical-session.target" ];
          };
          Install.WantedBy = [ "graphical-session.target" ];
          Service = {
            Type = "simple";
            # Use the system wrapper from i18n.inputMethod so selected addons
            # (e.g. fcitx5-chinese-addons) are available at runtime.
            ExecStart = "/run/current-system/sw/bin/fcitx5 --replace";
            Restart = "on-failure";
            RestartSec = 1;
          };
        };

        provider-app-vpn-ui = {
          Unit = {
            Description = "Provider app VPN GUI";
            After = [ "graphical-session.target" ];
            PartOf = [ "graphical-session.target" ];
          };
          Install.WantedBy = [ "graphical-session.target" ];
          Service = {
            Type = "simple";
            ExecStart = "${pkgs.provider-app-vpn}/bin/provider-app-vpn";
            Restart = "on-failure";
            RestartSec = 2;
          };
        };
      };
  };

  xdg = {
    configFile = {
      "qt6ct/qt6ct.conf".source = ./configs/qt6ct/qt6ct.conf;
      "qt6ct/colors/darker.conf".source = "${pkgs.qt6Packages.qt6ct}/share/qt6ct/colors/darker.conf";
      # 固化用户名路径，避免 Waybar 在特殊环境下无法展开 $USER。
      "waybar/config".text =
        builtins.replaceStrings
          [ "$USER" ]
          [ mainUser ]
          (builtins.readFile ./configs/waybar/config.jsonc);
      "waybar/style.css".source = ./configs/waybar/style.css;
      "wlogout/layout".source = ./configs/wlogout/layout;
      "wlogout/style.css".source = ./configs/wlogout/style.css;
      "wlogout/icons/lock.png".source = "${pkgs.wlogout}/share/wlogout/icons/lock.png";
      "wlogout/icons/logout.png".source = "${pkgs.wlogout}/share/wlogout/icons/logout.png";
      "wlogout/icons/suspend.png".source = "${pkgs.wlogout}/share/wlogout/icons/suspend.png";
      "wlogout/icons/hibernate.png".source = "${pkgs.wlogout}/share/wlogout/icons/hibernate.png";
      "wlogout/icons/reboot.png".source = "${pkgs.wlogout}/share/wlogout/icons/reboot.png";
      "wlogout/icons/shutdown.png".source = "${pkgs.wlogout}/share/wlogout/icons/shutdown.png";

      "fcitx5/profile" = {
        source = ./configs/fcitx5/profile;
        force = true;
      };

      "fuzzel/fuzzel.ini".source = ./configs/fuzzel/fuzzel.ini;
      "foot/foot.ini".source = ./configs/foot/foot.ini;
      "ghostty/config".source = ./configs/ghostty/config;
      "yazi/yazi.toml".source = ./configs/yazi/yazi.toml;
      "yazi/keymap.toml".source = ./configs/yazi/keymap.toml;
      "git/config".source = ./configs/git/config;
      "zellij/config.kdl".source = ./configs/zellij/config.kdl;
      "tmux/tmux.conf".source = ./configs/tmux/tmux.conf;
      "wallpapers/default.png".source = ./configs/wallpapers/1.png;

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

  dconf.settings = {
    # GTK 全局暗色偏好（Nautilus/libadwaita 等会跟随）
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "Adwaita-dark";
      icon-theme = "Papirus";
    };
  };

  # 质量守护：防止 home.packages 出现重复 derivation（同 outPath）
  assertions = [
    {
      assertion =
        let
          homePackageOutPaths = map (pkg: pkg.outPath) config.home.packages;
        in
        lib.length homePackageOutPaths == lib.length (lib.unique homePackageOutPaths);
      message = "Duplicate packages detected in home.packages (same outPath).";
    }
  ];
}
