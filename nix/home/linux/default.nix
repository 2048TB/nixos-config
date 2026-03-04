{ config
, pkgs
, lib
, myvars
, mainUser
, ...
}:
let
  homeStateVersion = myvars.homeStateVersion or "25.11";
  homeDir = config.home.homeDirectory;
  inherit (myvars) configRepoPath;

  waylandSession = pkgs.writeScript "wayland-session" ''
    #!/usr/bin/env bash
    hm_vars="/etc/profiles/per-user/${mainUser}/etc/profile.d/hm-session-vars.sh"
    if [ -f "$hm_vars" ]; then
      # shellcheck disable=SC1090
      . "$hm_vars"
    fi

    # greetd 启动链路下，systemd user 可能不会自动继承 HM session vars。
    # 显式导入 IM 相关变量，确保 user service / D-Bus 激活应用使用同一输入法环境。
    export XDG_CURRENT_DESKTOP="''${XDG_CURRENT_DESKTOP:-niri}"
    export XDG_SESSION_DESKTOP="''${XDG_SESSION_DESKTOP:-niri}"
    /run/current-system/sw/bin/systemctl --user import-environment \
      INPUT_METHOD GTK_IM_MODULE QT_IM_MODULE XMODIFIERS SDL_IM_MODULE \
      XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP || true
    /run/current-system/sw/bin/dbus-update-activation-environment --systemd \
      INPUT_METHOD GTK_IM_MODULE QT_IM_MODULE XMODIFIERS SDL_IM_MODULE \
      XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP || true

    exec /run/current-system/sw/bin/niri-session
  '';
in
{
  _module.args.userProfileBin = "/etc/profiles/per-user/${mainUser}/bin";

  imports = [
    ../base
    ./desktop.nix
    ./packages.nix
    ./programs.nix
    ./xdg.nix
  ];

  home = {
    username = mainUser;
    homeDirectory = "/home/${mainUser}";
    stateVersion = homeStateVersion;

    # 会话变量（仅 Linux 特有：Wayland/输入法/OpenSSL/PYTHONUSERBASE）
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

      # Linux 特有工具链路径
      PYTHONUSERBASE = "${homeDir}/.local";
      # OpenSSL for Rust openssl-sys on NixOS (user-wide)
      OPENSSL_INCLUDE_DIR = "${pkgs.openssl.dev}/include";
      OPENSSL_LIB_DIR = "${pkgs.openssl.out}/lib";
      OPENSSL_DIR = "${pkgs.openssl.dev}";
    };

    file = {
      # 便捷入口：保持 /etc/nixos 作为系统入口，同时在主目录提供快速访问路径
      "nixos".source = config.lib.file.mkOutOfStoreSymlink configRepoPath;

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

  # 避免 Fcitx5 首次启动时因目录尚未创建导致拼音历史文件读写报错。
  home.activation.ensureFcitxPinyinDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${homeDir}/.local/share/fcitx5/pinyin"
  '';

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
