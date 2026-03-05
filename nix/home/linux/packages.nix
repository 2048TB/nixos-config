{ pkgs
, pkgsUnstable
, lib
, mylib
, myvars
, mytheme
, ...
}:
let
  fractionalScale = "1.25";
  roleFlags = mylib.roleFlags myvars;
  inherit (roleFlags) enableMullvadVpn enableSteam enableLibvirtd enableDocker;
  # App toggles (flat host vars, default true)
  enableWpsOffice = myvars.enableWpsOffice or true;
  enableZathura = myvars.enableZathura or true;
  enableSplayer = myvars.enableSplayer or true;
  enableTelegramDesktop = myvars.enableTelegramDesktop or true;
  enableLocalSend = myvars.enableLocalSend or true;

  # 仅在混合显卡（amd-nvidia-hybrid）时安装 GPU 加速相关软件
  gpuChoice = myvars.gpuMode or "auto";
  isHybridGpu = gpuChoice == "amd-nvidia-hybrid";
  ollamaVulkan = pkgs.ollama or null;
  tensorflowCudaPkg = pkgs.python3Packages.tensorflowWithCuda or null;
  tensorflowCudaEnv =
    if tensorflowCudaPkg != null
    then pkgs.python3.withPackages (_: [ tensorflowCudaPkg ])
    else null;
  hashcatPkg = pkgs.hashcat or null;
  hybridPackages = lib.optionals isHybridGpu (
    lib.optional (ollamaVulkan != null) ollamaVulkan
    ++ lib.optional (tensorflowCudaEnv != null) tensorflowCudaEnv
    ++ lib.optional (hashcatPkg != null) hashcatPkg
  );

  # WPS Office steam-run 包装器
  # 修复 NixOS 上 WPS 无法启动的问题（FHS 兼容性）
  # 参考：https://github.com/NixOS/nixpkgs/issues/125951
  # 额外注入 Qt 缩放变量，确保 XWayland 应用在分数缩放下保持可读尺寸。
  wpsRunWrapper = bin: lib.hiPrio (pkgs.writeShellScriptBin bin ''
    exec env \
      QT_AUTO_SCREEN_SCALE_FACTOR=0 \
      QT_ENABLE_HIGHDPI_SCALING=1 \
      QT_SCALE_FACTOR=${fractionalScale} \
      QT_SCALE_FACTOR_ROUNDING_POLICY=PassThrough \
      ${lib.getExe pkgs.steam-run} ${pkgs.wpsoffice}/bin/${bin} "$@"
  '');
  wpsWrappedBins = map wpsRunWrapper [ "wps" "et" "wpp" "wpspdf" ];
  # WPS 上游 desktop 使用绝对 /nix/store 路径，需改写为命令名以命中包装器。
  wpsDesktopOverride =
    desktopFile: bin:
    pkgs.runCommand "wps-desktop-override-${bin}" { } ''
      cp ${pkgs.wpsoffice}/share/applications/${desktopFile} "$out"
      sed -E -i 's|^Exec=.*/bin/${bin}(.*)$|Exec=${bin}\1|' "$out"
    '';

  # 统一 Wlogout 调用入口，避免 Waybar/Niri 参数漂移
  wlogoutMenu = pkgs.writeShellApplication {
    name = "wlogout-menu";
    runtimeInputs = with pkgs; [ wlogout ];
    text = builtins.readFile ../../scripts/session/wlogout-menu.sh;
  };
  lockScreen = pkgs.writeShellApplication {
    name = "lock-screen";
    runtimeInputs = with pkgs; [ swaylock ];
    text = mytheme.apply (builtins.readFile ../../scripts/session/lock-screen.sh);
  };
  riverScreenshot = pkgs.writeShellApplication {
    name = "river-screenshot";
    runtimeInputs = with pkgs; [ grim slurp wl-clipboard coreutils ];
    text = builtins.readFile ../../scripts/session/screenshot.sh;
  };
  riverCliphistMenu = pkgs.writeShellApplication {
    name = "river-cliphist-menu";
    runtimeInputs = with pkgs; [ cliphist fuzzel wl-clipboard ];
    text = builtins.readFile ../../scripts/session/cliphist-menu.sh;
  };
  waybarClockCalendar = pkgs.writeShellApplication {
    name = "waybar-clock-calendar";
    runtimeInputs = with pkgs; [ fuzzel coreutils ];
    text = builtins.readFile ../../scripts/session/waybar-clock-calendar.sh;
  };
  waybarTemperatureStatus = pkgs.writeShellApplication {
    name = "waybar-temperature-status";
    runtimeInputs = with pkgs; [ coreutils ];
    text = builtins.readFile ../../scripts/session/waybar-temperature.sh;
  };
  publicIpStatus = pkgs.writeShellApplication {
    name = "public-ip-status";
    runtimeInputs = with pkgs; [ wget coreutils gnused ];
    text = builtins.readFile ../../scripts/session/public-ip-status.sh;
  };

  cherryStudioPackage = pkgsUnstable.cherry-studio;
  gamingPackages = with pkgs; [
    mangohud
    umu-launcher
    bbe
    wineWowPackages.stable # 原：stagingFull（避免触发本地编译）
    winetricks
    protonplus
  ];
  virtualisationPackages = with pkgs; [
    virt-viewer
    spice-gtk
    qemu_kvm
  ];
  dockerPackages = with pkgs; [
    docker-compose # Docker 编排工具
    dive # Docker 镜像分析
    lazydocker # Docker TUI 管理器
  ];
in
{
  home = {
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
      yq # YAML 处理器（查询、格式化、校验）
      yamllint # YAML lint/语法检查
      taplo # TOML 工具（fmt/lint/validate）
      check-jsonschema # JSON/YAML 的 JSON Schema 校验
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
      nomacs
      nautilus # GNOME 文件管理器（Wayland 原生，简洁现代）
      wsdd # 提供 gvfs-wsdd-wrapper 依赖，避免 Nautilus 网络发现报错
      file-roller # GNOME 压缩管理器（Nautilus 集成必需）
      ghostty
      foot # 轻量 Wayland 终端（备用）
      papirus-icon-theme # dconf/qt6ct 使用 Papirus 图标主题
      cherryStudioPackage # 多 LLM 提供商桌面客户端（来自 nixpkgs-unstable）

      # === Wayland 工具 ===
      satty
      swaylock # Niri 手动锁屏
      grim
      slurp
      wl-screenrec

      # === 基础图形工具 ===
      gnome-text-editor

      # 压缩/解压工具（命令行 + Nautilus file-roller 集成）
      p7zip-rar # 包含 7-Zip + RAR 支持（非自由许可）
      unrar
      unar
      arj
      zip
      unzip
      lrzip
      lzop

      # === 桌面工作流 ===
      fuzzel
      waybar
      wlogout
      gnome-calculator
      swaybg # 备用壁纸工具（手动/脚本场景可用）

      # === Wayland 基础设施 ===
      cliphist
      wl-clipboard
      qt6Packages.qt6ct
      app2unit
      polkit_gnome # Polkit 认证代理（权限提升对话框，virt-manager/Nautilus 等需要）
      networkmanagerapplet # nm-connection-editor（WiFi GUI 管理入口）
      pasystray # 托盘音量控制（恢复托盘区声音管理）

      # 媒体 / 图形
      pavucontrol
      pulsemixer
      imv
      libva-utils
      vdpauinfo
      vulkan-tools
      mesa-demos
      nvitop

      # === 语言/包管理补齐 ===
      bun
      pnpm
      pipx
    ]
    ++ hybridPackages
    ++ lib.optional enableLocalSend pkgs.localsend
    ++ lib.optional enableZathura pkgs.zathura
    ++ lib.optional enableSplayer pkgs.splayer
    ++ lib.optional enableTelegramDesktop pkgs.telegram-desktop
    ++ lib.optional enableWpsOffice pkgs.wpsoffice
    ++ lib.optionals enableSteam gamingPackages
    ++ lib.optionals enableLibvirtd virtualisationPackages
    ++ lib.optionals enableDocker dockerPackages
    ++ lib.optional enableMullvadVpn pkgs.mullvad-vpn
    ++ [
      wlogoutMenu
      lockScreen
      riverScreenshot
      riverCliphistMenu
      waybarClockCalendar
      waybarTemperatureStatus
      publicIpStatus
    ]
    ++ lib.optionals enableWpsOffice wpsWrappedBins; # WPS steam-run 包装器（覆盖原始二进制，修复启动问题）

    file = lib.optionalAttrs enableWpsOffice {
      ".local/share/applications/wps-office-wps.desktop".source =
        wpsDesktopOverride "wps-office-wps.desktop" "wps";
      ".local/share/applications/wps-office-et.desktop".source =
        wpsDesktopOverride "wps-office-et.desktop" "et";
      ".local/share/applications/wps-office-wpp.desktop".source =
        wpsDesktopOverride "wps-office-wpp.desktop" "wpp";
      ".local/share/applications/wps-office-pdf.desktop".source =
        wpsDesktopOverride "wps-office-pdf.desktop" "wpspdf";
      ".local/share/applications/wps-office-prometheus.desktop".source =
        wpsDesktopOverride "wps-office-prometheus.desktop" "wps";
    };
  };
}
