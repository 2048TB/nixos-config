{ config, pkgs, lib, myvars, mainUser, ... }:
let
  mkSymlink = config.lib.file.mkOutOfStoreSymlink;
  # 支持环境变量覆盖配置路径，向后兼容 vars/default.nix
  repoRoot =
    let
      envPath = builtins.getEnv "NIXOS_CONFIG_PATH";
      homePath = "${config.home.homeDirectory}/nixos-config";
    in
      if envPath != "" then envPath
      else if builtins.pathExists homePath then homePath
      else if builtins.pathExists myvars.configRoot then myvars.configRoot
      else homePath;
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

  home.username = mainUser;
  home.homeDirectory = "/home/${mainUser}";
  home.stateVersion = "25.11";

  # 允许全局工具安装到可写目录，避免写入 /nix/store
  home.sessionVariables = {
    NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.npm-global";
    BUN_INSTALL = "${config.home.homeDirectory}/.bun";
    BUN_INSTALL_BIN = "${config.home.homeDirectory}/.bun/bin";
    BUN_INSTALL_GLOBAL_DIR = "${config.home.homeDirectory}/.bun/install/global";
    BUN_INSTALL_CACHE_DIR = "${config.home.homeDirectory}/.bun/install/cache";
    UV_TOOL_DIR = "${config.home.homeDirectory}/.local/share/uv/tools";
    UV_TOOL_BIN_DIR = "${config.home.homeDirectory}/.local/bin";
    CARGO_HOME = "${config.home.homeDirectory}/.cargo";
    RUSTUP_HOME = "${config.home.homeDirectory}/.rustup";
    GOPATH = "${config.home.homeDirectory}/go";
    GOBIN = "${config.home.homeDirectory}/go/bin";
    PYTHONUSERBASE = "${config.home.homeDirectory}/.local";
    PIPX_HOME = "${config.home.homeDirectory}/.local/share/pipx";
    PIPX_BIN_DIR = "${config.home.homeDirectory}/.local/bin";
    GEM_HOME = "${config.home.homeDirectory}/.local/share/gem";
    GEM_PATH = "${config.home.homeDirectory}/.local/share/gem";
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/.npm-global/bin"
    "${config.home.homeDirectory}/.bun/bin"
    "${config.home.homeDirectory}/.cargo/bin"
    "${config.home.homeDirectory}/go/bin"
    "${config.home.homeDirectory}/.local/share/gem/bin"
    "${config.home.homeDirectory}/.local/bin"
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

  programs.swaylock.enable = true;
  programs.wlogout.enable = true;

  programs.mpv = {
    enable = true;
    defaultProfiles = [ "gpu-hq" ];
    scripts = [ pkgs.mpvScripts.mpris ];
  };

  services.playerctld.enable = true;

  home.packages = with pkgs; [
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

    # 通讯软件
    telegram-desktop  # 使用官方二进制包（原 nixpaks.telegram-desktop 会触发 30 分钟编译）
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

    "pnpm/rc".text = ''
      global-dir=${config.home.homeDirectory}/.local/share/pnpm/global
      global-bin-dir=${config.home.homeDirectory}/.local/bin
    '';
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
    ".yarnrc".text = ''
      prefix "${config.home.homeDirectory}/.local"
    '';
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

  systemd.user.services.fcitx5 = {
    Unit = {
      Description = "Fcitx5 Input Method";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = lib.getExe pkgs.fcitx5;
      Restart = "on-failure";
      RestartSec = 1;
      Environment = [
        "GTK_IM_MODULE=fcitx"
        "QT_IM_MODULE=fcitx"
        "XMODIFIERS=@im=fcitx"
        "SDL_IM_MODULE=fcitx"
      ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
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
