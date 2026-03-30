{ pkgs, lib, ... }:
let
  catExe = lib.getExe' pkgs.coreutils "cat";
  mkdirExe = lib.getExe' pkgs.coreutils "mkdir";
  dirnameExe = lib.getExe' pkgs.coreutils "dirname";

  locationCycle = pkgs.writeShellScript "rivertile-location-cycle" ''
    set -eu
    state="$HOME/.local/state/rivertile-location"
    ${mkdirExe} -p "$(${dirnameExe} "$state")"
    locations="left top right bottom"
    current=""
    [ -f "$state" ] && current=$(${catExe} "$state")
    case "$current" in
      left)   next=top ;;
      top)    next=right ;;
      right)  next=bottom ;;
      bottom) next=left ;;
      *)      next=top ;;
    esac
    echo "$next" > "$state"
    riverctl send-layout-cmd rivertile "main-location $next"
  '';
in
{
  wayland.windowManager.river = {
    enable = true;
    package = null; # NixOS programs.river-classic 提供安装
    # river 由 system profile 提供；显式禁用 HM 的 xwayland 包注入，
    # 避免与系统侧 programs.river-classic.xwayland.enable 产生重复 closure。
    xwayland.enable = false;
    # 显式固定 HM 的 systemd 集成，避免未来默认值变化影响 graphical-session 链路。
    systemd = {
      enable = true;
      variables = [
        "DISPLAY"
        "WAYLAND_DISPLAY"
        "XDG_CURRENT_DESKTOP"
        "NIXOS_OZONE_WL"
        "XCURSOR_THEME"
        "XCURSOR_SIZE"
        "QT_QPA_PLATFORMTHEME"
        "INPUT_METHOD"
        "GTK_IM_MODULE"
        "QT_IM_MODULE"
        "XMODIFIERS"
        "SDL_IM_MODULE"
      ];
    };
    settings = {
      border-width = 2;
      border-color-focused = "0x61afef"; # mytheme blue
      border-color-unfocused = "0x3e4451"; # mytheme bg2
      set-repeat = "50 300";
      default-layout = "rivertile";
      focus-follows-cursor = "normal";
      set-cursor-warp = "on-focus-change";

      # Passthrough 模式：远程桌面/VNC 时让所有按键穿透
      declare-mode = [ "passthrough" ];

      # SSD 规则：这些应用的装饰由 compositor 绘制
      rule-add = {
        ssd = [
          [ "-app-id" "'google-chrome'" ]
          [ "-app-id" "'steam'" ]
          [ "-app-id" "'virt-manager'" ]
        ];
        float = [
          [ "-app-id" "'pavucontrol'" ]
          [ "-app-id" "'nm-connection-editor'" ]
          [ "-app-id" "'imv'" ]
          [ "-app-id" "'nomacs'" ]
          [ "-app-id" "'org.gnome.FileRoller'" ]
          [ "-app-id" "'ghostty-float'" ]
        ];
      };

      # 鼠标绑定（声明式）
      map-pointer.normal = {
        "Super BTN_LEFT" = "move-view";
        "Super BTN_RIGHT" = "resize-view";
        "Super BTN_MIDDLE" = "toggle-float";
      };

      map = {
        # Passthrough 模式退出键
        passthrough."Super F11" = "enter-mode normal";

        normal = {
          # ===== 窗口管理 =====
          "Super Q" = "close";
          "Super Z" = "toggle-fullscreen";
          "Super W" = "toggle-float";
          "Super E" = "focus-view next";

          # ===== Passthrough 模式进入 =====
          "Super F11" = "enter-mode passthrough";

          # ===== 焦点移动（方向键）=====
          "Super Left" = "focus-view previous";
          "Super Down" = "focus-view next";
          "Super Up" = "focus-view previous";
          "Super Right" = "focus-view next";

          # ===== 窗口交换（SD）=====
          "Super S" = "swap previous";
          "Super D" = "swap next";

          # ===== 浮动窗口移动（Alt+方向键，像素级）=====
          "Super+Alt Left" = "move left 100";
          "Super+Alt Down" = "move down 100";
          "Super+Alt Up" = "move up 100";
          "Super+Alt Right" = "move right 100";

          # ===== 浮动窗口吸附（Alt+Ctrl+方向键）=====
          "Super+Alt+Control Left" = "snap left";
          "Super+Alt+Control Down" = "snap down";
          "Super+Alt+Control Up" = "snap up";
          "Super+Alt+Control Right" = "snap right";

          # ===== 浮动窗口缩放（Alt+Shift+方向键）=====
          "Super+Alt+Shift Left" = "resize horizontal -100";
          "Super+Alt+Shift Down" = "resize vertical 100";
          "Super+Alt+Shift Up" = "resize vertical -100";
          "Super+Alt+Shift Right" = "resize horizontal 100";

          # ===== 布局比例（FG）=====
          "Super F" = "send-layout-cmd rivertile \"main-ratio -0.1\"";
          "Super G" = "send-layout-cmd rivertile \"main-ratio +0.1\"";

          # ===== 主区数量（RT）=====
          "Super R" = "send-layout-cmd rivertile \"main-count +1\"";
          "Super T" = "send-layout-cmd rivertile \"main-count -1\"";

          # ===== 核心操作（XCVB）=====
          "Super X" = "spawn '${locationCycle}'";
          "Super C" = "zoom";
          "Super O" = "focus-output next";
          "Super V" = "spawn 'cliphist list | fuzzel -d | cliphist decode | wl-copy'";
          "Super B" = "send-to-output next";

          # ===== 程序启动 =====
          "Super Return" = "spawn ghostty";
          "Super Space" = "spawn fuzzel";

          # ===== 会话管理 =====
          "Super+Shift E" = "spawn wlogout";
          "Super+Shift L" = "spawn 'swaylock -f --clock --indicator --effect-blur 7x5'";
          "Super+Shift P" = "spawn 'wlopm --off *'";

          # ===== 截图 =====
          "Super A" = "spawn 'grim -g \"$(slurp)\" - | wl-copy'";
          "Super+Shift A" = "spawn 'grim - | wl-copy'";
          "None Print" = "spawn 'grim - | wl-copy'";

          # ===== 音量控制 =====
          "None XF86AudioRaiseVolume" = "spawn 'wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.02+ --limit 1.0'";
          "None XF86AudioLowerVolume" = "spawn 'wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.02-'";
          "None XF86AudioMute" = "spawn 'wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle'";
          "None XF86AudioMicMute" = "spawn 'wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle'";

          # ===== 媒体控制 =====
          "None XF86AudioPlay" = "spawn 'playerctl play-pause'";
          "None XF86AudioStop" = "spawn 'playerctl stop'";
          "None XF86AudioPrev" = "spawn 'playerctl previous'";
          "None XF86AudioNext" = "spawn 'playerctl next'";

          # ===== 亮度控制 =====
          "None XF86MonBrightnessUp" = "spawn 'brightnessctl --class=backlight set 1%+'";
          "None XF86MonBrightnessDown" = "spawn 'brightnessctl --class=backlight set 1%-'";

          # ===== 壁纸切换（顺序）=====
          "Super+Shift W" = "spawn 'systemctl --user start wallpaper-next'";

          # ===== 通知中心 =====
          "Super N" = "spawn 'swaync-client -t -sw'";
        };

        # 锁屏模式下的键位（音量/媒体/亮度）
        locked = {
          "None XF86AudioRaiseVolume" = "spawn 'wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.02+ --limit 1.0'";
          "None XF86AudioLowerVolume" = "spawn 'wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.02-'";
          "None XF86AudioMute" = "spawn 'wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle'";
          "None XF86AudioMicMute" = "spawn 'wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle'";
          "None XF86AudioPlay" = "spawn 'playerctl play-pause'";
          "None XF86AudioPrev" = "spawn 'playerctl previous'";
          "None XF86AudioNext" = "spawn 'playerctl next'";
          "None XF86MonBrightnessUp" = "spawn 'brightnessctl --class=backlight set 1%+'";
          "None XF86MonBrightnessDown" = "spawn 'brightnessctl --class=backlight set 1%-'";
        };
      };
    };
    extraConfig = ''
      # ===== Cursor theme =====
      # River compositor 不读取 XCURSOR_THEME/XCURSOR_SIZE 环境变量，
      # 需通过 riverctl 显式设置，否则非应用区域显示默认光标。
      riverctl set-cursor-theme Adwaita 24

      # ===== Tag 切换（bitmask）=====
      for i in $(seq 1 9); do
        tags=$((1 << (i - 1)))
        riverctl map normal Super "$i" set-focused-tags "$tags"
        riverctl map normal Super+Shift "$i" set-view-tags "$tags"
        riverctl map normal Super+Control "$i" toggle-focused-tags "$tags"
        riverctl map normal Super+Shift+Control "$i" toggle-view-tags "$tags"
      done
      all_tags=$(((1 << 32) - 1))
      riverctl map normal Super 0 set-focused-tags "$all_tags"
      riverctl map normal Super+Shift 0 set-view-tags "$all_tags"

      # ===== Layout generator（主区占 80%）=====
      rivertile -view-padding 6 -outer-padding 6 -main-ratio 0.6 &
    '';
  };
}
