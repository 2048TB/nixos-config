{ config, pkgs, lib, myvars, ... }:
let
  mkSymlink = config.lib.file.mkOutOfStoreSymlink;
  repoRoot = "${config.home.homeDirectory}/nixos-config";
  niriConf = "${repoRoot}/home/niri";
  noctaliaConf = "${repoRoot}/home/noctalia";
  fcitx5Conf = "${repoRoot}/home/fcitx5";
  ghosttyConf = "${repoRoot}/home/ghostty";
  shellConf = "${repoRoot}/home/shell";
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
  imports = [
    ./core     # 基础 CLI 工具
    ./gui      # GUI 应用
    ./dev      # 开发工具链
    ./desktop  # 桌面环境配置
    ./gaming   # 游戏工具
  ];

  home.username = myvars.username;
  home.homeDirectory = "/home/${myvars.username}";
  home.stateVersion = "25.11";

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
    # IME data
    rime-data

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

    # nixpaks
    nixpaks.telegram-desktop
  ];

  xdg.configFile = {
    "noctalia".source = mkSymlink "${noctaliaConf}";
    "qt6ct/qt6ct.conf".source = mkSymlink "${noctaliaConf}/qt6ct.conf";

    "fcitx5/profile" = {
      source = mkSymlink "${fcitx5Conf}/profile";
      force = true;
    };
    "mozc/config1.db".source = mkSymlink "${fcitx5Conf}/mozc-config1.db";

    "ghostty/config".source = mkSymlink "${ghosttyConf}/ghostty-config";
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
      RestartSec = 1;
      TimeoutStopSec = 10;
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
