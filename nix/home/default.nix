{ config, pkgs, lib, myvars, mainUser, dms, dgopFlake, ... }:
let
  # ===== 基础常量 =====
  homeStateVersion = "25.11";

  # 路径常量
  homeDir = config.home.homeDirectory;
  localBinDir = "${homeDir}/.local/bin";
  localShareDir = "${homeDir}/.local/share";
  userProfileBin = "/etc/profiles/per-user/${mainUser}/bin";
  profileCmd = cmd: "${userProfileBin}/${cmd}";

  # 共享 shell 工具路径（多个脚本复用）
  headBin = "${pkgs.coreutils}/bin/head";
  mkdirBin = "${pkgs.coreutils}/bin/mkdir";
  dateBin = "${pkgs.coreutils}/bin/date";
  nmcliBin = "/run/current-system/sw/bin/nmcli";
  btctlBin = "/run/current-system/sw/bin/bluetoothctl";

  # 图形会话 systemd user service 生成器（7 个服务共享骨架）
  mkGraphicalService =
    { description
    , execStart
    , partOf ? true
    , restart ? "on-failure"
    , restartSec ? 2
    , environment ? [ ]
    , unitExtra ? { }
    , extraService ? { }
    ,
    }: {
      Unit = {
        Description = description;
        After = [ "graphical-session.target" ];
      } // lib.optionalAttrs partOf {
        PartOf = [ "graphical-session.target" ];
      } // unitExtra;
      Install.WantedBy = [ "graphical-session.target" ];
      Service = {
        Type = "simple";
        ExecStart = execStart;
        Restart = restart;
        RestartSec = restartSec;
      } // lib.optionalAttrs (environment != [ ]) {
        Environment = environment;
      } // extraService;
    };

  # River 配置常量
  modeCycleCmd = profileCmd "river-mode-cycle";
  volumeCmd = "/run/current-system/sw/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@";
  playerCmd = profileCmd "playerctl";
  brightnessCmd = "${profileCmd "brightnessctl"} --class=backlight set";

  # 浮动模式方向绑定（move/resize/snap）
  floatDirections = [
    { key = "Left"; move = "left 100"; resize = "horizontal -100"; snap = "left"; }
    { key = "Down"; move = "down 100"; resize = "vertical 100"; snap = "down"; }
    { key = "Up"; move = "up 100"; resize = "vertical -100"; snap = "up"; }
    { key = "Right"; move = "right 100"; resize = "horizontal 100"; snap = "right"; }
    { key = "H"; move = "left 100"; resize = "horizontal -100"; snap = "left"; }
    { key = "J"; move = "down 100"; resize = "vertical 100"; snap = "down"; }
    { key = "K"; move = "up 100"; resize = "vertical -100"; snap = "up"; }
    { key = "L"; move = "right 100"; resize = "horizontal 100"; snap = "right"; }
  ];
  floatDirBinds = lib.concatMapStringsSep "\n"
    (d:
      "      riverctl map float None ${d.key} move ${d.move}\n"
      + "      riverctl map float Shift ${d.key} resize ${d.resize}\n"
      + "      riverctl map float Control ${d.key} snap ${d.snap}"
    )
    floatDirections;

  # 浮动模式退出键
  floatExitKeys = [ "Escape" "Return" "Space" ];
  floatExitBinds = lib.concatMapStringsSep "\n"
    (key:
      "      riverctl map float None ${key} spawn '${modeCycleCmd} set normal'"
    )
    floatExitKeys;

  # 窗口规则：自动浮动的应用 app-id
  floatAppIds = [
    "gnome-calculator"
    "blueman-manager"
    "nm-connection-editor"
    "imv"
    "nomacs"
  ];
  floatRules = lib.concatMapStringsSep "\n"
    (app: "      riverctl rule-add -app-id '${app}' float")
    floatAppIds;

  # 窗口规则：应用自动分配标签 (tag N 的 bitmask = 1 << (N-1))
  tagRules = [
    { appId = "ghostty"; tags = 1; } # tag 1: 终端
    { appId = "foot"; tags = 1; } # tag 1: 终端
    { appId = "google-chrome*"; tags = 2; } # tag 2: 浏览器
    { appId = "org.gnome.Nautilus"; tags = 4; } # tag 3: 文件管理
    { appId = "code"; tags = 8; } # tag 4: 编辑器
    { appId = "org.telegram.*"; tags = 16; } # tag 5: 通讯
    { appId = "splayer"; tags = 32; } # tag 6: 媒体
    { appId = "mpv"; tags = 32; } # tag 6: 媒体
  ];
  tagRulesStr = lib.concatMapStringsSep "\n"
    (r: "      riverctl rule-add -app-id '${r.appId}' tags ${toString r.tags}")
    tagRules;

  # 应用关联常量
  imageMimeTypes = [
    "image/jpeg"
    "image/png"
    "image/webp"
    "image/gif"
    "image/bmp"
    "image/tiff"
  ];
  imageApps = [ "org.nomacs.ImageLounge.desktop" "nomacs.desktop" ];

  # ===== 启动脚本与包装器 =====
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

    # 由 Home Manager 的 wayland.windowManager.hyprland.systemd.enable
    # 统一导入关键环境变量到 systemd user / dbus，避免重复导入。
    export XDG_CURRENT_DESKTOP=Hyprland
    export XDG_SESSION_DESKTOP=Hyprland
    exec /run/current-system/sw/bin/Hyprland
  '';
  dmsSessionBootstrap = pkgs.writeShellScript "dms-session-bootstrap" ''
    set -eu

    # greetd + user systemd 场景下 XDG_SESSION_ID 可能未注入到 dms.service 环境，
    # 会导致 logind GetSession("self") 失败并退化禁用 loginctl 集成。
    if [ -z "''${XDG_SESSION_ID:-}" ]; then
      uid="$(${pkgs.coreutils}/bin/id -u)"
      sid="$(${pkgs.systemd}/bin/loginctl show-user "$uid" -p Display --value 2>/dev/null || true)"
      if [ -n "$sid" ] && [ "$sid" != "n/a" ] && [ "$sid" != "-" ]; then
        export XDG_SESSION_ID="$sid"
      fi
    fi

    exec ${profileCmd "dms"} run --session
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
  dgopPackage =
    if pkgs ? dgop
    then pkgs.dgop
    else dgopFlake.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # WPS Office steam-run 包装器
  # 修复 NixOS 上 WPS 无法启动的问题（FHS 兼容性）
  # 参考：https://github.com/NixOS/nixpkgs/issues/125951
  wpsRunWrapper = bin: lib.hiPrio (pkgs.writeShellScriptBin bin ''
    exec ${lib.getExe pkgs.steam-run} ${pkgs.wpsoffice}/bin/${bin} "$@"
  '');
  wpsWrappedBins = map wpsRunWrapper [ "wps" "et" "wpp" "wpspdf" ];
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
  riverModeCycle = pkgs.writeShellScriptBin "river-mode-cycle" ''
    set -euo pipefail
    stateFile="${homeDir}/.local/state/river/mode"
    action="''${1:-toggle}"
    current="normal"
    next="normal"

    if [ -s "$stateFile" ]; then
      current="$(${pkgs.coreutils}/bin/head -n 1 "$stateFile")"
    fi

    case "$action" in
      toggle)
        case "$current" in
          normal) next="float" ;;
          float) next="passthrough" ;;
          passthrough) next="normal" ;;
          *) next="normal" ;;
        esac
        ;;
      set)
        next="''${2:-normal}"
        ;;
      *)
        echo "Usage: river-mode-cycle [toggle|set <normal|float|passthrough>]" >&2
        exit 1
        ;;
    esac

    case "$next" in
      normal|float|passthrough) ;;
      *) next="normal" ;;
    esac

    ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$stateFile")"
    printf '%s\n' "$next" > "$stateFile"
    exec /run/current-system/sw/bin/riverctl enter-mode "$next"
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

    pick_temp_input() {
      local preferred="" hwmon="" input="" name=""
      for preferred in k10temp coretemp cpu_thermal x86_pkg_temp zenpower; do
        for hwmon in /sys/class/hwmon/hwmon*; do
          [ -d "$hwmon" ] || continue
          [ -r "$hwmon/name" ] || continue
          name="$("${headBin}" -n 1 "$hwmon/name" 2>/dev/null || true)"
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

    raw="$("${headBin}" -n 1 "$inputFile" 2>/dev/null || true)"
    [[ "$raw" =~ ^[0-9]+$ ]] || exit 1

    tempC=$((raw / 1000))
    class="normal"
    icon="󰔄"
    if [ "$tempC" -ge 85 ]; then
      class="critical"
      icon=""
    elif [ "$tempC" -ge 75 ]; then
      class="warning"
      icon=""
    fi

    printf '{"text":"%s %s°C","class":"%s","tooltip":"Temperature: %s°C\\nSensor: %s"}\n' \
      "$icon" "$tempC" "$class" "$tempC" "''${inputFile%/*}"
  '';
  wifiRadioStatus = pkgs.writeShellScriptBin "wifi-radio-status" ''
    set -euo pipefail
    nmcli="${nmcliBin}"
    wifiState="$("$nmcli" -g WIFI general status 2>/dev/null || true)"
    wifiState="''${wifiState%%$'\n'*}"
    wifiState="''${wifiState,,}"

    case "$wifiState" in
      enabled) printf '󰖩\n' ;;
      disabled) printf '󰖪\n' ;;
      *) printf '󰖭\n' ;;
    esac
  '';
  wifiToggleRadio = pkgs.writeShellScriptBin "wifi-toggle-radio" ''
    set -euo pipefail
    nmcli="${nmcliBin}"
    wifiState="$("$nmcli" -g WIFI general status 2>/dev/null || true)"
    wifiState="''${wifiState%%$'\n'*}"
    wifiState="''${wifiState,,}"

    case "$wifiState" in
      enabled) exec "$nmcli" radio wifi off ;;
      *) exec "$nmcli" radio wifi on ;;
    esac
  '';
  wifiQuickMenu = pkgs.writeShellScriptBin "wifi-quick-menu" ''
    set -euo pipefail
    nmcli="${nmcliBin}"
    fuzzel="${pkgs.fuzzel}/bin/fuzzel"

    open_wifi_gui() {
      exec ${pkgs.networkmanagerapplet}/bin/nm-connection-editor
    }

    open_nmtui_fallback() {
      exec ${profileCmd "ghostty"} -e /run/current-system/sw/bin/nmtui
    }

    handle_wifi_open_action() {
      case "$1" in
        "󰖩 Open WiFi Connections (GUI)") open_wifi_gui ;;
        " Open nmtui (fallback)") open_nmtui_fallback ;;
        *) return 1 ;;
      esac
    }

    wifiState="$("$nmcli" -g WIFI general status 2>/dev/null || true)"
    wifiState="''${wifiState%%$'\n'*}"
    wifiState="''${wifiState,,}"
    [ -n "$wifiState" ] || wifiState="unknown"

    currentPayload=""
    while IFS= read -r line; do
      case "$line" in
        yes:*)
          currentPayload="''${line#yes:}"
          break
          ;;
      esac
    done < <("$nmcli" -t -f ACTIVE,SSID,SIGNAL dev wifi 2>/dev/null || true)

    if [ -n "$currentPayload" ]; then
      currentSignal="''${currentPayload##*:}"
      currentSsidEscaped="''${currentPayload%:*}"
      if [ "$currentSignal" = "$currentPayload" ]; then
        currentSignal="?"
        currentSsidEscaped="$currentPayload"
      fi
      currentSsid="''${currentSsidEscaped//\\:/:}"
      [ -n "$currentSsid" ] || currentSsid="<hidden>"
      [ -n "$currentSignal" ] || currentSignal="?"
      currentSsidDisplay="$currentSsid"
      currentSignalDisplay="''${currentSignal}%"
    else
      currentSsidDisplay="Not connected"
      currentSignalDisplay="-"
    fi

    if [ "$wifiState" = "enabled" ]; then
      toggleLabel="󰖪 Disable WiFi"
    else
      toggleLabel="󰖩 Enable WiFi"
    fi

    selected="$(
      {
        printf '%s\n' "$toggleLabel"
        printf '%s\n' "󰖩 WiFi Details"
        printf '%s\n' "󰖩 Open WiFi Connections (GUI)"
        printf '%s\n' " Open nmtui (fallback)"
      } | "$fuzzel" --dmenu --prompt 'WiFi > ' || true
    )"
    [ -n "$selected" ] || exit 0

    case "$selected" in
      "󰖩 Enable WiFi")
        exec "$nmcli" radio wifi on
        ;;
      "󰖪 Disable WiFi")
        exec "$nmcli" radio wifi off
        ;;
      "󰖩 WiFi Details")
        detailsSelected="$(
          {
            printf '%s\n' "Status: $wifiState"
            printf '%s\n' "Current SSID: $currentSsidDisplay"
            printf '%s\n' "Signal: $currentSignalDisplay"
            printf '%s\n' "---------------------------"
            printf '%s\n' "󰖩 Open WiFi Connections (GUI)"
            printf '%s\n' " Open nmtui (fallback)"
          } | "$fuzzel" --dmenu --prompt 'WiFi details > ' || true
        )"
        handle_wifi_open_action "$detailsSelected" || exit 0
        ;;
      *)
        handle_wifi_open_action "$selected" || exit 0
        ;;
    esac
  '';
  bluetoothQuickMenu = pkgs.writeShellScriptBin "bluetooth-quick-menu" ''
    set -euo pipefail
    btctl="${btctlBin}"
    fuzzel="${pkgs.fuzzel}/bin/fuzzel"

    open_bluetooth_gui() {
      exec /run/current-system/sw/bin/blueman-manager
    }

    open_bluetooth_cli() {
      exec ${profileCmd "ghostty"} -e /run/current-system/sw/bin/bluetoothctl
    }

    handle_bluetooth_open_action() {
      case "$1" in
        "󰂯 Open Bluetooth Devices (GUI)") open_bluetooth_gui ;;
        " Open bluetoothctl (fallback)") open_bluetooth_cli ;;
        *) return 1 ;;
      esac
    }

    powered="no"
    showOutput="$("$btctl" show 2>/dev/null || true)"
    case "$showOutput" in
      *"Powered: yes"*) powered="yes" ;;
    esac

    connectedRaw="$("$btctl" devices Connected 2>/dev/null || true)"
    connectedCount=0
    firstConnected="None"
    connectedDetails=""
    while IFS= read -r line; do
      case "$line" in
        Device\ *)
          deviceName="''${line#Device }"
          deviceName="''${deviceName#* }"
          [ -n "$deviceName" ] || deviceName="<unknown>"
          connectedCount=$((connectedCount + 1))
          if [ "$connectedCount" -eq 1 ]; then
            firstConnected="$deviceName"
          fi
          connectedDetails="''${connectedDetails}• $deviceName"$'\n'
          ;;
      esac
    done <<<"$connectedRaw"

    if [ "$powered" = "yes" ]; then
      toggleLabel="󰂲 Disable Bluetooth"
    else
      toggleLabel="󰂯 Enable Bluetooth"
    fi

    selected="$(
      {
        printf '%s\n' "$toggleLabel"
        printf '%s\n' "󰂯 Bluetooth Details"
        printf '%s\n' "󰂯 Open Bluetooth Devices (GUI)"
        printf '%s\n' " Open bluetoothctl (fallback)"
      } | "$fuzzel" --dmenu --prompt 'Bluetooth > ' || true
    )"
    [ -n "$selected" ] || exit 0

    case "$selected" in
      "󰂯 Enable Bluetooth")
        exec "$btctl" power on
        ;;
      "󰂲 Disable Bluetooth")
        exec "$btctl" power off
        ;;
      "󰂯 Bluetooth Details")
        detailsSelected="$(
          {
            printf '%s\n' "Power: $powered"
            printf '%s\n' "Connected count: $connectedCount"
            printf '%s\n' "Current device: $firstConnected"
            if [ "$connectedCount" -gt 0 ]; then
              printf '%s\n' "---------------------------"
              printf '%b' "$connectedDetails"
            fi
            printf '%s\n' "---------------------------"
            printf '%s\n' "󰂯 Open Bluetooth Devices (GUI)"
            printf '%s\n' " Open bluetoothctl (fallback)"
          } | "$fuzzel" --dmenu --prompt 'Bluetooth details > ' || true
        )"
        handle_bluetooth_open_action "$detailsSelected" || exit 0
        ;;
      *)
        handle_bluetooth_open_action "$selected" || exit 0
        ;;
    esac
  '';
  publicIpStatus = pkgs.writeShellScriptBin "public-ip-status" ''
    set -euo pipefail
    wgetBin="${pkgs.wget}/bin/wget"
    trBin="/run/current-system/sw/bin/tr"
    sedBin="/run/current-system/sw/bin/sed"
    cacheDir="${homeDir}/.cache/waybar"
    cacheFile="$cacheDir/public-ip"
    now="$("${dateBin}" +%s)"
    ip=""
    sourceLabel=""

    fetch_plain_ip() {
      local url="$1"
      "$wgetBin" -q --tries=1 -T 3 -O- "$url" 2>/dev/null | "${headBin}" -n 1 | "$trBin" -d '\r\n[:space:]' || true
    }

    fetch_trace_ip() {
      local url="$1"
      "$wgetBin" -q --tries=1 -T 3 -O- "$url" 2>/dev/null \
        | "$sedBin" -n 's/^ip=//p' \
        | "${headBin}" -n 1 \
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

      # Accept standard IPv6 forms (compressed or full) with hex and colon only.
      [[ "$ip" == *:* ]] || return 1
      [[ "$ip" =~ ^[0-9A-Fa-f:]+$ ]] || return 1
      return 0
    }

    for entry in \
      "https://api.ipify.org|ipify|plain" \
      "https://ifconfig.me/ip|ifconfig.me|plain" \
      "https://1.1.1.1/cdn-cgi/trace|cloudflare-trace|trace"; do
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
      "${mkdirBin}" -p "$cacheDir"
      printf '%s|%s|%s\n' "$now" "$ip" "$sourceLabel" > "$cacheFile"
      printf '{"text":"󰩠 %s","tooltip":"Public IP: %s\\nSource: %s\\nLeft: Quick menu\\nRight: nmtui","class":"online"}\n' "$ip" "$ip" "$sourceLabel"
      exit 0
    fi

    if [ -r "$cacheFile" ]; then
      cachedLine="$("${headBin}" -n 1 "$cacheFile" || true)"
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
          printf '{"text":"󰩠 %s","tooltip":"Public IP (cached %sm): %s\\nSource: %s\\nLeft: Quick menu\\nRight: nmtui","class":"online"}\n' "$cachedIp" "$ageMin" "$cachedIp" "''${cachedSrc:-cache}"
          exit 0
        fi
      fi
    fi

    printf '{"text":"󰪎 offline","tooltip":"Public IP unavailable\\nLeft: Quick menu\\nRight: nmtui","class":"offline"}\n'
  '';
  swaybgLauncher = pkgs.writeShellScript "swaybg-launcher" ''
    set -euo pipefail
    wallpaperDir="${homeDir}/.config/wallpapers"
    fallbackColor="#1e1e2e"

    randomWallpaper=""
    if [ -d "$wallpaperDir" ]; then
      randomWallpaper="$(
        ${pkgs.findutils}/bin/find "$wallpaperDir" -maxdepth 1 \
          \( -type f -o -type l \) \
          \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.gif' \) \
        | ${pkgs.coreutils}/bin/shuf \
        | ${pkgs.coreutils}/bin/head -n 1
      )"
    fi

    if [ -n "$randomWallpaper" ] && [ -r "$randomWallpaper" ]; then
      exec ${pkgs.swaybg}/bin/swaybg -i "$randomWallpaper" -m fill
    fi

    printf '%s\n' "swaybg-launcher: no readable wallpapers in $wallpaperDir, using solid color fallback" >&2
    exec ${pkgs.swaybg}/bin/swaybg -c "$fallbackColor" -m solid_color
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
        # playerctld 在空元数据时会触发 swaync 0.12.3 的 MPRIS 断言噪音
        # 保留 mpris 小组件，但忽略聚合器并在无元数据时自动隐藏
        autohide = true;
        blacklist = [
          "org.mpris.MediaPlayer2.playerctld"
          "playerctld"
        ];
      };
      notifications = { };
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
  imports = [
    dms.homeModules.dank-material-shell
  ];

  home = {
    username = mainUser;
    homeDirectory = "/home/${mainUser}";
    stateVersion = homeStateVersion;

    # 会话变量（普通 Linux 方案：用户级全局安装目录）
    sessionVariables = {
      # Wayland 支持
      # 关闭 NIXOS_OZONE_WL，避免 VSCode 启动时注入已弃用的 Electron 参数告警
      QT_QPA_PLATFORMTHEME = "qt6ct";
      # 明确指定 cursor theme，修复 GTK 组件在 Wayland 会话下找不到 arrow/hand2
      XCURSOR_THEME = "Adwaita";
      XCURSOR_SIZE = "24";
      # 输入法环境变量（Wayland 会话下显式声明，避免 Fcitx5 未接管）
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
      # 在 Hyprland 会话中显式使用 libsecret 后端，避免凭据存储后端选择不稳定导致重复口令提示
      (google-chrome.override { commandLineArgs = "--password-store=gnome-libsecret"; })
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
      adwaita-icon-theme # 提供 Adwaita cursor 资源（GTK/Quickshell 共用）
      papirus-icon-theme # dconf/qt6ct 使用 Papirus 图标主题
      cherry-studio # 多 LLM 提供商桌面客户端

      # === Wayland 工具 ===
      satty
      grim
      slurp
      wl-screenrec
      wlr-randr # Wayland 输出设置（备用）

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

      # === Hyprland / DMS 生态 ===
      gnome-calculator

      # === Wayland 基础设施 ===
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

      # === 语言/包管理补齐 ===
      bun
      pnpm
      pipx
    ]
    ++ hybridPackages
    ++ [
      wifiRadioStatus
      wifiToggleRadio
      wifiQuickMenu
      bluetoothQuickMenu
      publicIpStatus
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

  programs.dank-material-shell = {
    enable = true;
    systemd.enable = true;
    # 显式指定 dgop，确保 CPU/内存等系统监控小组件可用
    enableSystemMonitoring = true;
    dgop.package = dgopPackage;
    enableVPN = false; # 避免与 system packages 的 networkmanager 重叠
    # settings.json 由 activation 阶段写入可写文件，避免 HM 只读文件触发 DMS 写入告警
  };

  wayland.windowManager.hyprland = {
    enable = true;
    package = null; # 由 NixOS 的 programs.hyprland 安装
    portalPackage = null;
    systemd.enable = true;
    extraConfig = ''
      monitor = , preferred, auto, 1.25

      # 分数缩放下让 XWayland 应用走原生 1x 渲染，减少字体发虚
      xwayland {
        force_zero_scaling = true
      }

      input {
        kb_layout = us
        repeat_rate = 50
        repeat_delay = 300
        follow_mouse = 0
      }

      general {
        gaps_in = 6
        gaps_out = 2
        border_size = 2
        layout = dwindle
        col.active_border = rgba(89b4faff)
        col.inactive_border = rgba(313244ff)
      }

      decoration {
        rounding = 8
      }

      animations {
        enabled = true
        animation = windows, 1, 3, default
        animation = workspaces, 1, 4, default
      }

      misc {
        disable_hyprland_logo = true
        disable_splash_rendering = true
      }

      windowrulev2 = float,class:^(gnome-calculator)$
      windowrulev2 = float,class:^(blueman-manager)$
      windowrulev2 = float,class:^(nm-connection-editor)$
      windowrulev2 = float,class:^(imv)$
      windowrulev2 = float,class:^(nomacs)$

      # DMS 动态生成的 Hyprland 配置（主题/输出/布局）
      source = ~/.config/hypr/dms/colors.conf
      source = ~/.config/hypr/dms/outputs.conf
      source = ~/.config/hypr/dms/layout.conf
      source = ~/.config/hypr/dms/cursor.conf
      source = ~/.config/hypr/dms/windowrules.conf
      # 固定当前主显示器缩放，避免被旧的 dms/outputs.conf 缩放值覆盖
      monitor = DP-2, preferred, auto, 1.25

      # 应用与 DMS 快捷操作
      bind = SUPER, Return, exec, ${profileCmd "ghostty"}
      bind = SUPER, Space, exec, dms ipc call spotlight toggle
      bind = SUPER, B, exec, ${profileCmd "nautilus"}
      bind = SUPER, C, exec, dms ipc call clipboard toggle
      bind = SUPER CTRL, M, exec, dms ipc call processlist focusOrToggle
      bind = SUPER SHIFT, comma, exec, dms ipc call settings focusOrToggle
      bind = SUPER SHIFT, Y, exec, dms ipc call dankdash wallpaper
      bind = SUPER, X, exec, dms ipc call lock lock
      bind = SUPER SHIFT, X, exec, dms ipc call powermenu toggle
      bind = SUPER CTRL, N, exec, dms ipc call notifications toggle
      bind = SUPER SHIFT, N, exec, dms ipc call notepad toggle
      bind = SUPER, TAB, exec, dms ipc call hypr toggleOverview
      bind = SUPER SHIFT, Slash, exec, dms ipc call keybinds toggle hyprland

      # 窗口管理
      bind = SUPER, Q, killactive
      bind = SUPER SHIFT, E, exit
      bind = SUPER, Z, fullscreen, 1
      bind = SUPER SHIFT, Z, fullscreen, 0
      bind = SUPER, V, togglefloating
      bind = SUPER, G, togglegroup
      bind = SUPER, H, movewindow, l
      bind = SUPER, J, movewindow, d
      bind = SUPER, K, movewindow, u
      bind = SUPER, L, movewindow, r
      bind = SUPER, Home, focuswindow, first
      bind = SUPER, End, focuswindow, last
      bind = SUPER, A, exec, dms screenshot
      bind = SUPER, M, movewindow, mon:l
      bind = SUPER, N, movewindow, mon:r
      bind = SUPER SHIFT, H, movewindow, l
      bind = SUPER SHIFT, J, movewindow, d
      bind = SUPER SHIFT, K, movewindow, u
      bind = SUPER SHIFT, L, movewindow, r
      bind = SUPER, Left, movefocus, l
      bind = SUPER, Down, movefocus, d
      bind = SUPER, Up, movefocus, u
      bind = SUPER, Right, movefocus, r
      bind = SUPER ALT, H, swapwindow, l
      bind = SUPER ALT, J, swapwindow, d
      bind = SUPER ALT, K, swapwindow, u
      bind = SUPER ALT, L, swapwindow, r
      bind = SUPER ALT, Left, swapwindow, l
      bind = SUPER ALT, Down, swapwindow, d
      bind = SUPER ALT, Up, swapwindow, u
      bind = SUPER ALT, Right, swapwindow, r
      bind = SUPER, bracketleft, swapnext, prev
      bind = SUPER, bracketright, swapnext
      bind = SUPER CTRL, left, focusmonitor, l
      bind = SUPER CTRL, right, focusmonitor, r
      bind = SUPER CTRL, H, focusmonitor, l
      bind = SUPER CTRL, J, focusmonitor, d
      bind = SUPER CTRL, K, focusmonitor, u
      bind = SUPER CTRL, L, focusmonitor, r
      bind = SUPER SHIFT CTRL, left, movewindow, mon:l
      bind = SUPER SHIFT CTRL, down, movewindow, mon:d
      bind = SUPER SHIFT CTRL, up, movewindow, mon:u
      bind = SUPER SHIFT CTRL, right, movewindow, mon:r
      bind = SUPER SHIFT CTRL, H, movewindow, mon:l
      bind = SUPER SHIFT CTRL, J, movewindow, mon:d
      bind = SUPER SHIFT CTRL, K, movewindow, mon:u
      bind = SUPER SHIFT CTRL, L, movewindow, mon:r
      bind = SUPER SHIFT, bracketleft, layoutmsg, preselect l
      bind = SUPER SHIFT, bracketright, layoutmsg, preselect r
      bind = SUPER, R, layoutmsg, togglesplit
      bind = SUPER CTRL, F, resizeactive, exact 100%
      binde = SUPER, minus, resizeactive, -10% 0
      binde = SUPER, equal, resizeactive, 10% 0
      binde = SUPER, semicolon, resizeactive, 0 -10%
      binde = SUPER, apostrophe, resizeactive, 0 10%

      # 工作区
      bind = SUPER, comma, workspace, e+1
      bind = SUPER, period, workspace, e-1
      bind = CTRL SHIFT, R, exec, dms ipc call workspace-rename open
      bind = SUPER, 1, workspace, 1
      bind = SUPER, 2, workspace, 2
      bind = SUPER, 3, workspace, 3
      bind = SUPER, 4, workspace, 4
      bind = SUPER, 5, workspace, 5
      bind = SUPER, 6, workspace, 6
      bind = SUPER, 7, workspace, 7
      bind = SUPER, 8, workspace, 8
      bind = SUPER, 9, workspace, 9
      bind = SUPER ALT, grave, togglespecialworkspace, magic
      bind = SUPER SHIFT, grave, movetoworkspacesilent, special:magic
      bind = SUPER, O, movetoworkspace, e+1
      bind = SUPER, P, movetoworkspace, e-1
      bind = SUPER, U, movetoworkspacesilent, e+1
      bind = SUPER, I, movetoworkspacesilent, e-1
      bind = SUPER SHIFT, 1, movetoworkspace, 1
      bind = SUPER SHIFT, 2, movetoworkspace, 2
      bind = SUPER SHIFT, 3, movetoworkspace, 3
      bind = SUPER SHIFT, 4, movetoworkspace, 4
      bind = SUPER SHIFT, 5, movetoworkspace, 5
      bind = SUPER SHIFT, 6, movetoworkspace, 6
      bind = SUPER SHIFT, 7, movetoworkspace, 7
      bind = SUPER SHIFT, 8, movetoworkspace, 8
      bind = SUPER SHIFT, 9, movetoworkspace, 9
      # MOD + 滚轮缩放活动窗口（Hyprland 官方支持 mouse_up/mouse_down）
      bind = SUPER, mouse_up, resizeactive, 40 40
      bind = SUPER, mouse_down, resizeactive, -40 -40

      # 媒体与亮度（DMS IPC）
      bindel = , XF86AudioRaiseVolume, exec, dms ipc call audio increment 3
      bindel = , XF86AudioLowerVolume, exec, dms ipc call audio decrement 3
      bindl = , XF86AudioMute, exec, dms ipc call audio mute
      bindl = , XF86AudioMicMute, exec, dms ipc call audio micmute
      bindl = , XF86AudioPause, exec, dms ipc call mpris playPause
      bindl = , XF86AudioPlay, exec, dms ipc call mpris playPause
      bindl = , XF86AudioPrev, exec, dms ipc call mpris previous
      bindl = , XF86AudioNext, exec, dms ipc call mpris next
      bindel = CTRL, XF86AudioRaiseVolume, exec, dms ipc call mpris increment 3
      bindel = CTRL, XF86AudioLowerVolume, exec, dms ipc call mpris decrement 3
      bindel = , XF86MonBrightnessUp, exec, dms ipc call brightness increment 5
      bindel = , XF86MonBrightnessDown, exec, dms ipc call brightness decrement 5

      # 截图（Print 系列保留）
      bind = , Print, exec, dms screenshot
      bind = CTRL, Print, exec, dms screenshot full
      bind = ALT, Print, exec, dms screenshot window

      # 系统
      bind = SUPER SHIFT, P, dpms, toggle

      # 鼠标拖拽
      bindm = SUPER, mouse:272, movewindow
      bindm = SUPER, mouse:273, resizewindow
    '';
  };

  services = {
    swaync = {
      enable = true;
      settings = swayncSettings;
      style = swayncStyle;
    };

    # DMS 已可直接使用 MPRIS；关闭 playerctld 避免无活动播放器时的重复告警
    playerctld.enable = false;

    # USB 设备自动挂载服务
    udiskie = {
      enable = true;
      automount = true;
      notify = true;
      tray = "never"; # Wayland 会话使用 DMS 托盘
    };
  };

  systemd = {
    user.services = {
      # 压制 Quickshell 非关键噪音日志（不影响功能）
      dms.Service = {
        ExecStart = lib.mkForce "${dmsSessionBootstrap}";
        Environment = [
          "QT_LOGGING_RULES=quickshell.I3.ipc.warning=false;qt.core.qfuture.continuations.warning=false;quickshell.service.sni.watcher.warning=false;qt.qpa.services.warning=false;qt.qpa.wayland.textinput.warning=false"
        ];
      };

      # 在 greetd + Hyprland 会话中显式拉起输入法，避免仅依赖 XDG autostart 导致未启动
      fcitx5 = mkGraphicalService {
        description = "Fcitx5 input method daemon";
        # Use the system wrapper from i18n.inputMethod so selected addons
        # (e.g. fcitx5-chinese-addons) are available at runtime.
        execStart = "/run/current-system/sw/bin/fcitx5 --replace";
        restartSec = 1;
      };

      mullvad-vpn-ui = mkGraphicalService {
        description = "Mullvad VPN GUI";
        execStart = "${pkgs.mullvad-vpn}/bin/mullvad-vpn";
        unitExtra = {
          Wants = [ "dms.service" ];
          After = [ "graphical-session.target" "dms.service" ];
        };
        environment = [
          # Mullvad wrapper 仅注入 coreutils/grep PATH；补齐 gsettings 与图形库搜索路径
          "PATH=${pkgs.glib}/bin:/run/current-system/sw/bin:${userProfileBin}"
          "LD_LIBRARY_PATH=${pkgs.libglvnd}/lib:/run/opengl-driver/lib:/run/opengl-driver-32/lib:/run/current-system/sw/lib"
          "LIBGL_DRIVERS_PATH=/run/opengl-driver/lib/dri"
          "GSETTINGS_SCHEMA_DIR=${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas"
        ];
      };
    };
  };

  xdg = {
    configFile =
      {
        "fcitx5/profile" = {
          source = ./configs/fcitx5/profile;
          force = true;
        };

        "foot/foot.ini".source = ./configs/foot/foot.ini;
        "ghostty/config".source = ./configs/ghostty/config;
        "yazi/yazi.toml".source = ./configs/yazi/yazi.toml;
        "yazi/keymap.toml".source = ./configs/yazi/keymap.toml;
        "git/config".source = ./configs/git/config;
        "zellij/config.kdl".source = ./configs/zellij/config.kdl;
        "tmux/tmux.conf".source = ./configs/tmux/tmux.conf;
        "wallpapers" = {
          source = ./configs/wallpapers;
          recursive = true;
        };
        "qt6ct/qt6ct.conf".source = ./configs/qt6ct/qt6ct.conf;

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

  home.activation = {
    ensureDmsStateFiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      dmsConfigDir="${homeDir}/.config/DankMaterialShell"
      dmsCacheDir="${homeDir}/.cache/DankMaterialShell"
      hyprDmsDir="${homeDir}/.config/hypr/dms"

      ${mkdirBin} -p "$dmsConfigDir" "$dmsCacheDir" "$hyprDmsDir"

      # 旧代可能遗留 Nix store 的只读 symlink；转换为可写普通文件
      if [ -L "$dmsConfigDir/settings.json" ]; then
        settingsLinkTarget="$(${pkgs.coreutils}/bin/readlink "$dmsConfigDir/settings.json" || true)"
        ${pkgs.coreutils}/bin/rm -f "$dmsConfigDir/settings.json"
        if [ -n "$settingsLinkTarget" ] && [ -f "$settingsLinkTarget" ]; then
          ${pkgs.coreutils}/bin/cp "$settingsLinkTarget" "$dmsConfigDir/settings.json"
        else
          printf '{}\n' > "$dmsConfigDir/settings.json"
        fi
      fi

      if [ ! -e "$dmsConfigDir/settings.json" ]; then
        printf '{}\n' > "$dmsConfigDir/settings.json"
      fi

      if ! ${pkgs.jq}/bin/jq -e '.' "$dmsConfigDir/settings.json" >/dev/null 2>&1; then
        printf '{}\n' > "$dmsConfigDir/settings.json"
      fi

      settingsTmp="$dmsConfigDir/settings.json.tmp"
      if ${pkgs.jq}/bin/jq \
        '.osdPowerProfileEnabled = false
         | .showSeconds = true
         | .weatherEnabled = false
         | .showCpuUsage = true
         | .showMemUsage = true' \
        "$dmsConfigDir/settings.json" > "$settingsTmp"; then
        ${pkgs.coreutils}/bin/mv "$settingsTmp" "$dmsConfigDir/settings.json"
      else
        ${pkgs.coreutils}/bin/rm -f "$settingsTmp"
      fi

      if [ ! -e "$dmsConfigDir/plugin_settings.json" ]; then
        printf '{}\n' > "$dmsConfigDir/plugin_settings.json"
      fi

      if [ ! -e "$dmsCacheDir/cache.json" ]; then
        printf '{}\n' > "$dmsCacheDir/cache.json"
      fi

      if [ ! -e "$hyprDmsDir/cursor.conf" ]; then
        printf '\n' > "$hyprDmsDir/cursor.conf"
      fi

      if [ ! -e "$hyprDmsDir/windowrules.conf" ]; then
        printf '\n' > "$hyprDmsDir/windowrules.conf"
      fi

      # 清理历史兼容 shim（其输出固定为 {}，会导致 DMS CPU/内存小组件无数据）
      legacyDgop="${homeDir}/.local/bin/dgop"
      if [ -f "$legacyDgop" ] && ${pkgs.gnugrep}/bin/grep -q "dgop compatibility shim" "$legacyDgop"; then
        ${pkgs.coreutils}/bin/rm -f "$legacyDgop"
      fi
    '';
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
