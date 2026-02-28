{ config, pkgs, lib, myvars, mainUser, ... }:
let
  # ===== 基础常量 =====
  homeStateVersion = "25.11";

  # 路径常量
  homeDir = config.home.homeDirectory;
  localBinDir = "${homeDir}/.local/bin";
  localShareDir = "${homeDir}/.local/share";
  userProfileBin = "/etc/profiles/per-user/${mainUser}/bin";
  profileCmd = cmd: "${userProfileBin}/${cmd}";
  fractionalScale = "1.25";

  # 资源映射常量
  wlogoutIconNames = [
    "lock"
    "logout"
    "suspend"
    "hibernate"
    "reboot"
    "shutdown"
  ];
  wlogoutIconFiles =
    lib.genAttrs
      (map (name: "wlogout/icons/${name}.png") wlogoutIconNames)
      (path: { source = "${pkgs.wlogout}/share/${path}"; });

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
  portalInterfaces = import ../lib/portal-interfaces.nix { };
  portalDefaults = portalInterfaces.defaultBackends;
  portalGtkInterfaces = portalInterfaces.gtkInterfaces;
  portalHyprlandInterfaces = portalInterfaces.hyprlandInterfaces;
  workspaceIds = map toString (lib.range 1 10);
  waybarPersistentWorkspaceEntries =
    let
      len = builtins.length workspaceIds;
    in
    lib.concatStringsSep "\n" (
      builtins.genList
        (i:
          let
            ws = builtins.elemAt workspaceIds i;
            suffix = if i + 1 < len then "," else "";
          in
          "      \"${ws}\": []${suffix}")
        len
    );
  hyprlandLayoutGetFunction = ''
    get_layout() {
      local fallback="$1"
      local layout=""
      if [ -x "$hyprctlBin" ]; then
        layout="$("$hyprctlBin" -j getoption general:layout 2>/dev/null | "$jqBin" -r '.str // empty' 2>/dev/null || true)"
      fi
      case "$layout" in
        master|scrolling) printf '%s\n' "$layout" ;;
        *) printf '%s\n' "$fallback" ;;
      esac
    }
  '';
  mkSessionService = target: description: serviceConfig: {
    Unit = {
      Description = description;
      After = [ target ];
      PartOf = [ target ];
    };
    Install.WantedBy = [ target ];
    Service = serviceConfig;
  };
  mkHyprlandSessionService = mkSessionService "hyprland-session.target";
  mkGraphicalSessionService = mkSessionService "graphical-session.target";

  # ===== 启动脚本与包装器 =====
  waylandSession = pkgs.writeScript "wayland-session" ''
    #!/usr/bin/env bash
    hm_vars="/etc/profiles/per-user/${mainUser}/etc/profile.d/hm-session-vars.sh"
    if [ -f "$hm_vars" ]; then
      # shellcheck disable=SC1090
      . "$hm_vars"
    fi

    # 由 Home Manager 的 wayland.windowManager.hyprland.systemd.enable
    # 统一导入关键环境变量到 systemd user / dbus，避免重复导入。

    # 尝试结束旧会话，避免残留服务状态影响新会话
    if systemctl --user is-active hyprland-session.target >/dev/null 2>&1; then
      systemctl --user stop hyprland-session.target
    fi
    if [ -x /run/current-system/sw/bin/start-hyprland ]; then
      exec /run/current-system/sw/bin/start-hyprland
    fi
    exec /run/current-system/sw/bin/Hyprland
  '';

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
  # 额外注入 Qt 缩放变量，配合 Hyprland xwayland.force_zero_scaling 避免“清晰但过小”。
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
  screenshotTool = pkgs.writeShellScriptBin "screenshot-tool" ''
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
  cliphistMenu = pkgs.writeShellScriptBin "cliphist-menu" ''
    set -euo pipefail
    picked="$(${pkgs.cliphist}/bin/cliphist list | ${pkgs.fuzzel}/bin/fuzzel --dmenu || true)"
    [ -n "$picked" ] || exit 0
    printf '%s' "$picked" | ${pkgs.cliphist}/bin/cliphist decode | ${pkgs.wl-clipboard}/bin/wl-copy
  '';
  hyprlandSubmapCycle = pkgs.writeShellScriptBin "hyprland-submap-cycle" ''
    set -euo pipefail
    stateFile="${homeDir}/.local/state/hyprland/submap"
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
        echo "Usage: hyprland-submap-cycle [toggle|set <normal|float|passthrough>]" >&2
        exit 1
        ;;
    esac

    case "$next" in
      normal|float|passthrough) ;;
      *) next="normal" ;;
    esac

    ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$stateFile")"
    printf '%s\n' "$next" > "$stateFile"
    if [ "$next" = "normal" ]; then
      exec /run/current-system/sw/bin/hyprctl dispatch submap reset
    fi
    exec /run/current-system/sw/bin/hyprctl dispatch submap "$next"
  '';
  hyprlandLayoutToggle = pkgs.writeShellScriptBin "hyprland-layout-toggle" ''
    set -euo pipefail
    hyprctlBin="/run/current-system/sw/bin/hyprctl"
    jqBin="${pkgs.jq}/bin/jq"

    ${hyprlandLayoutGetFunction}

    current="$(get_layout unknown)"
    case "$current" in
      scrolling) next="master" ;;
      master) next="scrolling" ;;
      *) next="scrolling" ;;
    esac

    exec "$hyprctlBin" keyword general:layout "$next"
  '';
  hyprlandLayoutDispatch = pkgs.writeShellScriptBin "hyprland-layout-dispatch" ''
    set -euo pipefail
    hyprctlBin="/run/current-system/sw/bin/hyprctl"
    jqBin="${pkgs.jq}/bin/jq"
    action="''${1:-}"

    ${hyprlandLayoutGetFunction}

    dispatch_layoutmsg() {
      local msg="$1"
      exec "$hyprctlBin" dispatch layoutmsg "$msg"
    }

    layout="$(get_layout scrolling)"
    case "$action" in
      focus)
        if [ "$layout" = "master" ]; then
          dispatch_layoutmsg "swapwithmaster"
        else
          dispatch_layoutmsg "fit active"
        fi
        ;;
      grow)
        if [ "$layout" = "master" ]; then
          dispatch_layoutmsg "mfact +0.05"
        else
          dispatch_layoutmsg "colresize +0.05"
        fi
        ;;
      shrink)
        if [ "$layout" = "master" ]; then
          dispatch_layoutmsg "mfact -0.05"
        else
          dispatch_layoutmsg "colresize -0.05"
        fi
        ;;
      right)
        if [ "$layout" = "master" ]; then
          dispatch_layoutmsg "addmaster"
        else
          dispatch_layoutmsg "move +col"
        fi
        ;;
      left)
        if [ "$layout" = "master" ]; then
          dispatch_layoutmsg "removemaster"
        else
          dispatch_layoutmsg "move -col"
        fi
        ;;
      shift-up)
        if [ "$layout" = "master" ]; then
          dispatch_layoutmsg "orientationtop"
        else
          dispatch_layoutmsg "colresize +conf"
        fi
        ;;
      shift-right)
        if [ "$layout" = "master" ]; then
          dispatch_layoutmsg "orientationright"
        else
          dispatch_layoutmsg "swapcol r"
        fi
        ;;
      shift-down)
        if [ "$layout" = "master" ]; then
          dispatch_layoutmsg "orientationbottom"
        else
          dispatch_layoutmsg "colresize -conf"
        fi
        ;;
      shift-left)
        if [ "$layout" = "master" ]; then
          dispatch_layoutmsg "orientationleft"
        else
          dispatch_layoutmsg "swapcol l"
        fi
        ;;
      *)
        echo "Usage: hyprland-layout-dispatch [focus|grow|shrink|right|left|shift-up|shift-right|shift-down|shift-left]" >&2
        exit 1
        ;;
    esac
  '';
  hyprGeneratedConfig =
    let
      workspaceKeybindings = map
        (workspace: {
          key = if workspace == "10" then "0" else workspace;
          inherit workspace;
        })
        workspaceIds;
      mkWorkspaceBindLines = dispatcher: modifier:
        let
          modifierSuffix = if modifier == "" then "" else " ${modifier}";
        in
        lib.concatStringsSep "\n" (
          map
            (entry: "bind = $mainMod${modifierSuffix}, ${entry.key}, ${dispatcher}, ${entry.workspace}")
            workspaceKeybindings
        );
      hyprFloatWindowRules = [
        {
          classPattern = "^(org\\.pulseaudio\\.pavucontrol|pavucontrol)$";
          size = "980 700";
        }
        {
          classPattern = "^(blueman-manager)$";
          size = "900 620";
        }
        {
          classPattern = "^(nm-connection-editor|Nm-connection-editor)$";
          size = "980 700";
        }
      ];
      mkHyprFloatWindowRuleTriplet = rule:
        lib.concatStringsSep "\n" [
          "windowrule = match:class ${rule.classPattern}, float 1"
          "windowrule = match:class ${rule.classPattern}, size ${rule.size}"
          "windowrule = match:class ${rule.classPattern}, center 1"
        ];
    in
    {
      persistentWorkspaces =
        lib.concatStringsSep "\n" (
          map (ws: "workspace = ${ws}, persistent:true") workspaceIds
        );
      workspaceSwitchBinds = mkWorkspaceBindLines "workspace" "";
      workspaceMoveBinds = mkWorkspaceBindLines "movetoworkspace" "SHIFT";
      workspaceSilentMoveBinds = mkWorkspaceBindLines "movetoworkspacesilent" "ALT";
      floatWindowRuleTriplets =
        lib.concatStringsSep "\n" (map mkHyprFloatWindowRuleTriplet hyprFloatWindowRules);
    };
  hyprlandConfig =
    builtins.replaceStrings
      [
        "@HOME_DIR@"
        "@PROFILE_BIN@"
        "@PLAYERCTL_BIN@"
        "@SCREENSHOT_BIN@"
        "@HYPR_PERSISTENT_WORKSPACES@"
        "@HYPR_FLOAT_WINDOW_RULE_TRIPLETS@"
        "@HYPR_WORKSPACE_SWITCH_BINDS@"
        "@HYPR_WORKSPACE_MOVE_BINDS@"
        "@HYPR_WORKSPACE_SILENT_MOVE_BINDS@"
      ]
      [
        homeDir
        userProfileBin
        "${pkgs.playerctl}/bin/playerctl"
        "${screenshotTool}/bin/screenshot-tool"
        hyprGeneratedConfig.persistentWorkspaces
        hyprGeneratedConfig.floatWindowRuleTriplets
        hyprGeneratedConfig.workspaceSwitchBinds
        hyprGeneratedConfig.workspaceMoveBinds
        hyprGeneratedConfig.workspaceSilentMoveBinds
      ]
      (builtins.readFile ./configs/hypr/hyprland.conf);
  hypridleConfig =
    builtins.replaceStrings
      [
        "@PROFILE_BIN@"
      ]
      [
        userProfileBin
      ]
      (builtins.readFile ./configs/hypr/hypridle.conf);
  hyprlockConfig = builtins.readFile ./configs/hypr/hyprlock.conf;
  waybarConfig =
    builtins.replaceStrings
      [
        "@USER_BIN@"
        "@SYSTEM_BIN@"
        "@WAYBAR_PERSISTENT_WORKSPACES@"
      ]
      [
        userProfileBin
        "/run/current-system/sw/bin"
        waybarPersistentWorkspaceEntries
      ]
      (builtins.readFile ./configs/waybar/config.jsonc);
  waybarStyle =
    builtins.replaceStrings
      [
        "@WAYBAR_PACMAN_ICON@"
      ]
      [
        "${./configs/waybar/icons/pacman.svg}"
      ]
      (builtins.readFile ./configs/waybar/style.css);
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
  waybarLayoutMode = pkgs.writeShellScriptBin "waybar-layout-mode" ''
    set -euo pipefail
    hyprctlBin="/run/current-system/sw/bin/hyprctl"
    jqBin="${pkgs.jq}/bin/jq"

    layout="$("$hyprctlBin" -j getoption general:layout 2>/dev/null | "$jqBin" -r '.str // empty' 2>/dev/null || true)"
    case "$layout" in
      master)
        text="主从"
        class="master"
        ;;
      scrolling)
        text="滚动"
        class="scrolling"
        ;;
      *)
        text="未知"
        class="unknown"
        ;;
    esac

    printf '{"text":"%s","class":"%s","tooltip":"当前布局：%s"}\n' "$text" "$class" "$text"
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
      icon=""
    elif [ "$tempC" -ge 75 ]; then
      class="warning"
      icon=""
    fi

    printf '{"text":"%s %s°C","class":"%s","tooltip":"Temperature: %s°C\\nSensor: %s"}\n' \
      "$icon" "$tempC" "$class" "$tempC" "''${inputFile%/*}"
  '';
  waybarBacklightStatus = pkgs.writeShellScriptBin "waybar-backlight-status" ''
    set -euo pipefail
    headBin="${pkgs.coreutils}/bin/head"

    pick_backlight_dir() {
      local dir=""
      for dir in /sys/class/backlight/*; do
        [ -d "$dir" ] || continue
        [ -r "$dir/brightness" ] || continue
        [ -r "$dir/max_brightness" ] || continue
        printf '%s\n' "$dir"
        return 0
      done
      return 1
    }

    backlightDir="$(pick_backlight_dir || true)"
    [ -n "$backlightDir" ] || exit 1

    current="$("$headBin" -n 1 "$backlightDir/brightness" 2>/dev/null || true)"
    maximum="$("$headBin" -n 1 "$backlightDir/max_brightness" 2>/dev/null || true)"
    [[ "$current" =~ ^[0-9]+$ ]] || exit 1
    [[ "$maximum" =~ ^[0-9]+$ ]] || exit 1
    [ "$maximum" -gt 0 ] || exit 1

    percent=$((current * 100 / maximum))
    icon="󰃟"
    if [ "$percent" -lt 34 ]; then
      icon="󰃞"
    elif [ "$percent" -ge 67 ]; then
      icon="󰃠"
    fi

    printf '{"text":"%s %s%%","class":"normal","tooltip":"Backlight: %s%%"}\n' "$icon" "$percent" "$percent"
  '';
  waybarBatteryStatus = pkgs.writeShellScriptBin "waybar-battery-status" ''
    set -euo pipefail
    headBin="${pkgs.coreutils}/bin/head"

    pick_battery_dir() {
      local dir=""
      for dir in /sys/class/power_supply/BAT*; do
        [ -d "$dir" ] || continue
        [ -r "$dir/capacity" ] || continue
        printf '%s\n' "$dir"
        return 0
      done
      return 1
    }

    batteryDir="$(pick_battery_dir || true)"
    [ -n "$batteryDir" ] || exit 1

    capacity="$("$headBin" -n 1 "$batteryDir/capacity" 2>/dev/null || true)"
    status="$("$headBin" -n 1 "$batteryDir/status" 2>/dev/null || true)"
    [[ "$capacity" =~ ^[0-9]+$ ]] || exit 1
    [ -n "$status" ] || status="Unknown"

    class="normal"
    icon=""
    if [ "$status" = "Charging" ] || [ "$status" = "Full" ]; then
      class="charging"
      icon=""
    else
      if [ "$capacity" -le 10 ]; then
        class="critical"
      elif [ "$capacity" -le 20 ]; then
        class="warning"
      fi

      if [ "$capacity" -lt 25 ]; then
        icon=""
      elif [ "$capacity" -lt 50 ]; then
        icon=""
      elif [ "$capacity" -lt 75 ]; then
        icon=""
      elif [ "$capacity" -lt 95 ]; then
        icon=""
      else
        icon=""
      fi
    fi

    printf '{"text":"%s %s%%","class":"%s","tooltip":"Battery: %s%%\\nStatus: %s"}\n' \
      "$icon" "$capacity" "$class" "$capacity" "$status"
  '';
  waybarLauncher = pkgs.writeShellScript "waybar-launcher" ''
    set -euo pipefail
    runtimeDir="''${XDG_RUNTIME_DIR:-/run/user/$(${pkgs.coreutils}/bin/id -u)}"
    waybarBin="${pkgs.waybar}/bin/waybar"
    basenameBin="${pkgs.coreutils}/bin/basename"
    dirnameBin="${pkgs.coreutils}/bin/dirname"
    sleepBin="${pkgs.coreutils}/bin/sleep"
    seqBin="${pkgs.coreutils}/bin/seq"

    launch_if_ready() {
      if [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && [ -S "$runtimeDir/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" ]; then
        exec "$waybarBin"
      fi

      for socket in "$runtimeDir"/hypr/*/.socket2.sock; do
        [ -S "$socket" ] || continue
        export HYPRLAND_INSTANCE_SIGNATURE="$("$basenameBin" "$("$dirnameBin" "$socket")")"
        exec "$waybarBin"
      done

      return 1
    }

    for _ in $("$seqBin" 1 100); do
      launch_if_ready || true
      "$sleepBin" 0.1
    done

    exit 1
  '';
  wifiQuickMenu = pkgs.writeShellScriptBin "wifi-quick-menu" ''
    set -euo pipefail
    nmcli="/run/current-system/sw/bin/nmcli"
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
    btctl="/run/current-system/sw/bin/bluetoothctl"
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

      # Accept standard IPv6 forms (compressed or full) with hex and colon only.
      [[ "$ip" == *:* ]] || return 1
      [[ "$ip" =~ ^[0-9A-Fa-f:]+$ ]] || return 1
      return 0
    }

    for entry in \
      "https://api.ipify.org|ipify|plain" \
      "https://ifconfig.me/ip|ifconfig.me|plain" \
      "http://1.1.1.1/cdn-cgi/trace|cloudflare-trace|trace"; do
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
      printf '{"text":"󰩠 %s","tooltip":"Public IP: %s\\nSource: %s\\nLeft: Quick menu\\nRight: nmtui","class":"online"}\n' "$ip" "$ip" "$sourceLabel"
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
          printf '{"text":"󰩠 %s","tooltip":"Public IP (cached %sm): %s\\nSource: %s\\nLeft: Quick menu\\nRight: nmtui","class":"online"}\n' "$cachedIp" "$ageMin" "$cachedIp" "''${cachedSrc:-cache}"
          exit 0
        fi
      fi
    fi

    printf '{"text":"IP N/A","tooltip":"Public IP unavailable\\nLeft: Quick menu\\nRight: nmtui","class":"offline"}\n'
  '';
  swaybgLauncher = pkgs.writeShellScript "swaybg-launcher" ''
    set -euo pipefail
    wallpaperDir="${homeDir}/.config/wallpapers"
    wallpaper="$wallpaperDir/1.png"

    randomWallpaper="$(
      ${pkgs.findutils}/bin/find "$wallpaperDir" -maxdepth 1 \
        \( -type f -o -type l \) \
        \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.gif' \) \
      | ${pkgs.coreutils}/bin/shuf \
      | ${pkgs.coreutils}/bin/head -n 1
    )"
    if [ -n "$randomWallpaper" ]; then
      wallpaper="$randomWallpaper"
    fi

    exec ${pkgs.swaybg}/bin/swaybg -i "$wallpaper" -m fill
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
      # 暂时移除 mpris：swaync 0.12.3 在当前会话下启动期会触发 GTK assertion。
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
    .control-center .widget-dnd {
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
      # 在分数缩放（如 1.25）下，优先让 Chromium/Electron 应用走原生 Wayland，
      # 避免落到 XWayland 后出现字体发虚。
      NIXOS_OZONE_WL = "1";
      QT_QPA_PLATFORMTHEME = "qt6ct";
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
      papirus-icon-theme # dconf/qt6ct 使用 Papirus 图标主题
      cherry-studio # 多 LLM 提供商桌面客户端

      # === Wayland 工具 ===
      satty
      hypridle # Hyprland 空闲管理（锁屏/熄屏/休眠）
      hyprlock # Hyprland 锁屏
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
      screenshotTool
      cliphistMenu
      hyprlandSubmapCycle
      hyprlandLayoutToggle
      hyprlandLayoutDispatch
      waybarClockCalendar
      waybarLayoutMode
      waybarTemperatureStatus
      waybarBacklightStatus
      waybarBatteryStatus
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

  wayland.windowManager.hyprland = {
    enable = true;
    package = null; # 由 NixOS 的 programs.hyprland 安装
    portalPackage = null; # 与 package 保持同源，避免版本混用
    xwayland.enable = true;
    systemd.enable = true;
    extraConfig = hyprlandConfig;
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
        polkit-gnome-authentication-agent-1 = mkGraphicalSessionService "polkit-gnome-authentication-agent-1" {
          Type = "simple";
          ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
          Restart = "on-failure";
          RestartSec = 1;
          TimeoutStopSec = 10;
        };

        # Clipboard history
        cliphist-daemon = mkGraphicalSessionService "cliphist clipboard history daemon" {
          Type = "simple";
          ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store";
          Restart = "always";
          RestartSec = 2;
        };

        hypridle = mkHyprlandSessionService "Hypridle idle daemon" {
          Type = "simple";
          ExecStart = "${pkgs.hypridle}/bin/hypridle";
          Restart = "on-failure";
          RestartSec = 2;
        };

        waybar = mkHyprlandSessionService "Waybar status bar" {
          Type = "simple";
          Environment = [
            "LANG=zh_CN.UTF-8"
            "LC_ALL=zh_CN.UTF-8"
            "LC_TIME=zh_CN.UTF-8"
          ];
          # 某些第三方托盘项（例如 chrome status icon）不提供 icon/pixmap，
          # Waybar 会持续打印固定错误；先做定向降噪。
          LogFilterPatterns = [
            "~Item '': No icon name or pixmap given."
            "~Item 'chrome_status_icon_1': No icon name or pixmap given."
            "~Unable to replace properties on 0: Error getting properties for ID"
          ];
          ExecStart = "${waybarLauncher}";
          Restart = "always";
          RestartSec = 2;
        };

        # 显式启动托盘来源进程，避免依赖 xdg-desktop-autostart.target 未激活时缺图标。
        nm-applet = mkGraphicalSessionService "NetworkManager applet" {
          Type = "simple";
          ExecStart = "${profileCmd "nm-applet"} --indicator";
          Restart = "on-failure";
          RestartSec = 2;
        };

        blueman-applet = mkGraphicalSessionService "Blueman applet" {
          Type = "simple";
          ExecStart = "${pkgs.blueman}/bin/blueman-applet";
          Restart = "on-failure";
          RestartSec = 2;
        };

        # udiskie 在中文 locale 下会触发 Python logging format KeyError（'信息'）
        # 将其 locale 固定为 C.UTF-8，避免格式化字段被翻译。
        udiskie.Service.Environment = [
          "LANG=C.UTF-8"
          "LC_ALL=C.UTF-8"
        ];

        # swaync 0.12.x 在空 MPRIS metadata 时会产生已知断言噪音。
        swaync.Service.LogFilterPatterns = [
          "~sway_notification_center_widgets_mpris_mpris_player_update_album_art: assertion 'metadata != NULL' failed"
          "~sway_notification_center_widgets_mpris_mpris_player_update_title: assertion 'metadata != NULL' failed"
          "~sway_notification_center_widgets_mpris_mpris_player_update_sub_title: assertion 'metadata != NULL' failed"
          "~sway_notification_center_widgets_mpris_mpris_player_update_buttons: assertion 'metadata != NULL' failed"
          "~gtk_native_get_surface: assertion 'GTK_IS_NATIVE (self)' failed"
        ];

        swaybg = mkGraphicalSessionService "Wallpaper daemon (swaybg)" {
          Type = "simple";
          ExecStart = "${swaybgLauncher}";
          Restart = "on-failure";
          RestartSec = 2;
        };

        # 在 greetd + Hyprland 会话中显式拉起输入法，避免仅依赖 XDG autostart 导致未启动
        fcitx5 = mkGraphicalSessionService "Fcitx5 input method daemon" {
          Type = "simple";
          # Use the system wrapper from i18n.inputMethod so selected addons
          # (e.g. fcitx5-chinese-addons) are available at runtime.
          ExecStart = "/run/current-system/sw/bin/fcitx5 --replace";
          Restart = "on-failure";
          RestartSec = 1;
        };

        provider-app-vpn-ui = mkGraphicalSessionService "Provider app VPN GUI" {
          Type = "simple";
          Environment = [
            # Provider app wrapper 仅注入 coreutils/grep PATH；补齐 gsettings 与图形库搜索路径
            "PATH=${pkgs.glib}/bin:/run/current-system/sw/bin:${userProfileBin}"
            "LD_LIBRARY_PATH=${pkgs.libglvnd}/lib:/run/opengl-driver/lib:/run/opengl-driver-32/lib:/run/current-system/sw/lib"
            "LIBGL_DRIVERS_PATH=/run/opengl-driver/lib/dri"
            "GSETTINGS_SCHEMA_DIR=${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas"
          ];
          ExecStart = "${pkgs.provider-app-vpn}/bin/provider-app-vpn";
          Restart = "on-failure";
          RestartSec = 2;
        };
      };
  };

  xdg = {
    configFile =
      {
        "qt6ct/qt6ct.conf".source = ./configs/qt6ct/qt6ct.conf;
        "qt6ct/colors/darker.conf".source = "${pkgs.qt6Packages.qt6ct}/share/qt6ct/colors/darker.conf";
        "waybar/config".text = waybarConfig;
        "waybar/style.css".text = waybarStyle;
        "waybar/icons" = {
          source = ./configs/waybar/icons;
          recursive = true;
          force = true;
        };
        "hypr/hyprlock.conf".text = hyprlockConfig;
        "hypr/hypridle.conf".text = hypridleConfig;
        "wlogout/layout".source = ./configs/wlogout/layout;
        "wlogout/style.css".source = ./configs/wlogout/style.css;

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
        "wallpapers" = {
          source = ./configs/wallpapers;
          recursive = true;
        };

        "pnpm/rc".text = ''
          global-dir=${localShareDir}/pnpm/global
          global-bin-dir=${localShareDir}/pnpm/bin
        '';
      }
      // wlogoutIconFiles;

    # Home Manager 会设置 NIX_XDG_DESKTOP_PORTAL_DIR，并优先从用户 profile 读取 .portal。
    # 需显式注入 gtk backend，否则在 Hyprland 会出现 "Requested gtk.portal is unrecognized"，
    # 进而导致 org.freedesktop.portal.Settings/FileChooser 缺失。
    portal = {
      enable = lib.mkForce true;
      xdgOpenUsePortal = true;
      extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
      config = {
        common = {
          default = portalDefaults;
        } // portalGtkInterfaces;
        hyprland = portalHyprlandInterfaces;
      };
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

  # Cursor theme：Adwaita 已在 closure 中（GTK 应用隐式依赖），不增加额外构建负担。
  # 同时为 Waybar/GTK 提供完整 cursor name set（hand2、arrow 等），消除加载告警。
  home.pointerCursor = {
    gtk.enable = true;
    package = pkgs.adwaita-icon-theme;
    name = "Adwaita";
    size = 24;
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
