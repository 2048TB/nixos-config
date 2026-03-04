{ config
, pkgs
, pkgsUnstable
, lib
, myvars
, ...
}:
let
  homeDir = config.home.homeDirectory;
  fractionalScale = "1.25";
  roleFlags = import ../../modules/system/role-flags.nix { inherit myvars; };
  inherit (roleFlags) enableProvider appVpn enableSteam enableLibvirtd enableDocker;
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
  lockScreen = pkgs.writeShellScriptBin "lock-screen" ''
    set -euo pipefail

    wallpaper="$HOME/.config/wallpapers/1.png"
    if [ ! -f "$wallpaper" ]; then
      wallpaper=""
    fi

    args=(
      --font "Maple Mono NF CN"
      --font-size 22
      --indicator-idle-visible
      --indicator-caps-lock
      --indicator-radius 110
      --indicator-thickness 10
      --line-color 00000000
      --separator-color 00000000
      --inside-color 313244ee
      --ring-color 89b4faff
      --text-color cdd6f4ff
      --inside-clear-color 313244ee
      --ring-clear-color f9e2afff
      --text-clear-color cdd6f4ff
      --inside-ver-color 313244ee
      --ring-ver-color a6e3a1ff
      --text-ver-color cdd6f4ff
      --inside-wrong-color 313244ee
      --ring-wrong-color f38ba8ff
      --text-wrong-color cdd6f4ff
      --key-hl-color a6e3a1ff
      --bs-hl-color f38ba8ff
      --show-failed-attempts
      --show-keyboard-layout
      --scaling fill
    )

    if [ -n "$wallpaper" ]; then
      args+=(--image "$wallpaper")
    else
      args+=(--color 1e1e2eff)
    fi

    exec ${pkgs.swaylock}/bin/swaylock -f "''${args[@]}" "$@"
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
  waybarClockCalendar = pkgs.writeShellScriptBin "waybar-clock-calendar" ''
    set -euo pipefail
    calBin="/run/current-system/sw/bin/cal"
    fuzzel="${pkgs.fuzzel}/bin/fuzzel"
    dateBin="/run/current-system/sw/bin/date"

    monthTitle="$("$dateBin" '+%Y-%m')"
    {
      printf '%s\n' "Calendar $monthTitle"
      "$calBin"
    } | "$fuzzel" --dmenu --prompt 'Date > ' --lines 10 >/dev/null || true
  '';
  waybarTemperatureStatus = pkgs.writeShellScriptBin "waybar-temperature-status" ''
    set -euo pipefail
    headBin="${pkgs.coreutils}/bin/head"

    pick_temp_input() {
      local preferred="" hwmon="" input="" name=""
      for preferred in k10temp coretemp cpu_thermal x86_pkg_temp zenpower; do
        for hwmon in /sys/class/hwmon/hwmon*; do
          [ -d "$hwmon" ] || continue
          [ -r "$hwmon/name" ] || continue
          name="$("$headBin" -n 1 "$hwmon/name" 2>/dev/null || true)"
          [ "$name" = "$preferred" ] || continue
          for input in "$hwmon"/temp*_input; do
            [ -r "$input" ] || continue
            printf '%s\n' "$input"
            return 0
          done
        done
      done

      for input in /sys/class/hwmon/hwmon*/temp*_input; do
        [ -r "$input" ] || continue
        printf '%s\n' "$input"
        return 0
      done
      return 1
    }

    inputFile="$(pick_temp_input || true)"
    [ -n "$inputFile" ] || exit 1

    raw="$("$headBin" -n 1 "$inputFile" 2>/dev/null || true)"
    [[ "$raw" =~ ^[0-9]+$ ]] || exit 1

    tempC=$((raw / 1000))
    class="normal"
    icon="󰔄"
    if [ "$tempC" -ge 85 ]; then
      class="critical"
      icon=""
    elif [ "$tempC" -ge 75 ]; then
      class="warning"
      icon=""
    fi

    printf '{"text":"%s %s°C","class":"%s","tooltip":"Temperature: %s°C\\nSensor: %s"}\n' \
      "$icon" "$tempC" "$class" "$tempC" "''${inputFile%/*}"
  '';
  publicIpStatus = pkgs.writeShellScriptBin "public-ip-status" ''
    set -euo pipefail
    wgetBin="${pkgs.wget}/bin/wget"
    trBin="/run/current-system/sw/bin/tr"
    sedBin="/run/current-system/sw/bin/sed"
    mkdirBin="${pkgs.coreutils}/bin/mkdir"
    headBin="${pkgs.coreutils}/bin/head"
    dateBin="${pkgs.coreutils}/bin/date"
    cacheDir="${homeDir}/.cache/waybar"
    cacheFile="$cacheDir/public-ip"
    now="$("$dateBin" +%s)"
    ip=""
    sourceLabel=""

    fetch_plain_ip() {
      local url="$1"
      "$wgetBin" -q --tries=1 -T 3 -O- "$url" 2>/dev/null | "$headBin" -n 1 | "$trBin" -d '\r\n[:space:]' || true
    }

    fetch_trace_ip() {
      local url="$1"
      "$wgetBin" -q --tries=1 -T 3 -O- "$url" 2>/dev/null \
        | "$sedBin" -n 's/^ip=//p' \
        | "$headBin" -n 1 \
        | "$trBin" -d '\r\n[:space:]' || true
    }

    is_valid_ipv4() {
      local ip="$1"
      local o1="" o2="" o3="" o4="" extra="" octet=""

      IFS='.' read -r o1 o2 o3 o4 extra <<< "$ip"
      [ -z "$extra" ] || return 1

      for octet in "$o1" "$o2" "$o3" "$o4"; do
        [[ "$octet" =~ ^[0-9]{1,3}$ ]] || return 1
        [ "$octet" -le 255 ] || return 1
      done
    }

    is_valid_ip() {
      local ip="$1"
      if is_valid_ipv4 "$ip"; then
        return 0
      fi

      [[ "$ip" == *:* ]] || return 1
      [[ "$ip" =~ ^[0-9A-Fa-f:]+$ ]] || return 1
      return 0
    }

    for entry in \
      "https://api.ipify.org|ipify|plain" \
      "https://ifconfig.me/ip|ifconfig.me|plain" \
      "https://www.cloudflare.com/cdn-cgi/trace|cloudflare-trace|trace"; do
      url="''${entry%%|*}"
      rest="''${entry#*|}"
      label="''${rest%%|*}"
      parser="''${rest#*|}"

      case "$parser" in
        plain) candidate="$(fetch_plain_ip "$url")" ;;
        trace) candidate="$(fetch_trace_ip "$url")" ;;
        *) candidate="" ;;
      esac

      if [ -n "$candidate" ] && is_valid_ip "$candidate"; then
        ip="$candidate"
        sourceLabel="$label"
        break
      fi
    done

    if [ -n "$ip" ]; then
      "$mkdirBin" -p "$cacheDir"
      printf '%s|%s|%s\n' "$now" "$ip" "$sourceLabel" > "$cacheFile"
      printf '{"text":"󰩠 %s","tooltip":"Public IP: %s\\nSource: %s\\nLeft: Connections GUI\\nRight: nmtui","class":"online"}\n' "$ip" "$ip" "$sourceLabel"
      exit 0
    fi

    if [ -r "$cacheFile" ]; then
      cachedLine="$("$headBin" -n 1 "$cacheFile" || true)"
      cachedTs="''${cachedLine%%|*}"
      cachedRest="''${cachedLine#*|}"
      cachedIp="''${cachedRest%%|*}"
      cachedSrc="''${cachedRest#*|}"

      if ! [[ "$cachedTs" =~ ^[0-9]+$ ]]; then
        cachedTs=0
      fi

      if [ "$cachedTs" -gt 0 ] && [ -n "$cachedIp" ] && is_valid_ip "$cachedIp"; then
        age=$((now - cachedTs))
        if [ "$age" -ge 0 ] && [ "$age" -le 1800 ]; then
          ageMin=$((age / 60))
          printf '{"text":"󰩠 %s","tooltip":"Public IP (cached %sm): %s\\nSource: %s\\nLeft: Connections GUI\\nRight: nmtui","class":"online"}\n' "$cachedIp" "$ageMin" "$cachedIp" "''${cachedSrc:-cache}"
          exit 0
        fi
      fi
    fi

    printf '{"text":"IP N/A","tooltip":"Public IP unavailable\\nLeft: Connections GUI\\nRight: nmtui","class":"offline"}\n'
  '';

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
    ++ lib.optional enableProvider appVpn pkgs.provider-app-vpn
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
