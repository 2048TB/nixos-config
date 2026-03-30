{ lib, isLaptop }:
let
  modulesRight =
    [ "mpris" "cpu" "memory" "network" "pulseaudio" ]
    ++ lib.optional isLaptop "battery"
    ++ [ "idle_inhibitor" "custom/notification" "tray" ];
in
{
  layer = "top";
  position = "top";
  height = 29;
  spacing = 5;
  reload_style_on_change = true;

  modules-left = [ "custom/launcher" "clock" "river/window" ];
  modules-center = [ "river/tags" ];
  modules-right = modulesRight ++ [ "custom/power" ];

  "river/tags" = {
    num-tags = 9;
    tag-labels = [ "1" "2" "3" "4" "5" "6" "7" "8" "9" ];
  };

  "river/window" = {
    format = "{}";
    max-length = 36;
  };

  clock = {
    format = " {:L%Y-%m-%d %A %H:%M:%S}";
    locale = "zh_CN.UTF-8";
    interval = 1;
    tooltip-format = "<big>{:L%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
    calendar = {
      mode = "month";
      on-scroll = 1;
    };
    actions = {
      on-click-right = "mode";
      on-scroll-up = "shift_up";
      on-scroll-down = "shift_down";
      on-click-middle = "shift_reset";
    };
  };

  mpris = {
    format = "{player_icon} {dynamic}";
    format-paused = "{status_icon} <i>{dynamic}</i>";
    dynamic-len = 30;
    player-icons = {
      default = "▶";
      mpv = "🎵";
      chromium = "";
    };
    status-icons = {
      paused = "⏸";
    };
    ignored-players = [ "firefox" ];
  };

  cpu = {
    format = "󰻠 {usage}%";
    interval = 5;
    states = {
      warning = 70;
      critical = 90;
    };
  };

  memory = {
    format = "󰍛 {}%";
    interval = 5;
    states = {
      warning = 75;
      critical = 90;
    };
  };

  network = {
    format-wifi = " ↑ {bandwidthUpBits} ↓ {bandwidthDownBits}";
    format-ethernet = "󰈀 ↑ {bandwidthUpBits} ↓ {bandwidthDownBits}";
    format-linked = "↑ -- ↓ --";
    format-disconnected = "󰤭 Disconnected";
    tooltip-format-wifi = " {essid} ({signalStrength}%)\n{ipaddr}\n↑ {bandwidthUpBits} ↓ {bandwidthDownBits}";
    tooltip-format-ethernet = "󰈀 {ifname}\n{ipaddr}\n↑ {bandwidthUpBits} ↓ {bandwidthDownBits}";
    tooltip-format-disconnected = "Disconnected";
    interval = 2;
  };

  pulseaudio = {
    format = "{icon} {volume}%";
    format-muted = "󰝟 muted";
    format-icons = {
      default = [ "󰕿" "󰖀" "󰕾" ];
    };
    on-click = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
    on-scroll-up = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%+";
    on-scroll-down = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-";
    tooltip-format = "{desc}\n{volume}%";
  };

  battery = {
    interval = 30;
    states = {
      warning = 30;
      critical = 15;
    };
    format = "{icon} {capacity}%";
    format-charging = "󰂄 {capacity}%";
    format-plugged = "󰚥 {capacity}%";
    format-full = "󰁹 Full";
    format-icons = [ "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
    tooltip-format = "{timeTo}\n{capacity}% — {power:.1f}W";
  };

  idle_inhibitor = {
    format = "{icon}";
    format-icons = {
      activated = "";
      deactivated = "";
    };
    tooltip-format-activated = "Idle inhibitor: ON";
    tooltip-format-deactivated = "Idle inhibitor: OFF";
  };

  "custom/notification" = {
    tooltip = true;
    format = "{icon}";
    format-icons = {
      notification = "";
      none = "";
      dnd-notification = "";
      dnd-none = "";
      inhibited-notification = "";
      inhibited-none = "";
      dnd-inhibited-notification = "";
      dnd-inhibited-none = "";
    };
    return-type = "json";
    exec-if = "which swaync-client";
    exec = "swaync-client -swb";
    on-click = "swaync-client -t -sw";
    on-click-right = "swaync-client -d -sw";
    escape = true;
  };

  "custom/launcher" = {
    format = "󱄅";
    tooltip = false;
    on-click = "fuzzel";
  };

  tray = {
    spacing = 5;
    icon-size = 13;
    show-passive-items = true;
  };

  "custom/power" = {
    format = "⏻";
    tooltip = false;
    on-click = "wlogout";
  };
}
