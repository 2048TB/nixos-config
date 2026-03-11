{ config
, pkgs
, lib
, mainUser
, ...
}:
let
  homeDir = config.home.homeDirectory;

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
  home = {
    # 会话变量（仅 Linux 特有：Wayland/输入法/OpenSSL）
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

      # OpenSSL for Rust openssl-sys on NixOS (user-wide)
      OPENSSL_INCLUDE_DIR = "${pkgs.openssl.dev}/include";
      OPENSSL_LIB_DIR = "${pkgs.openssl.out}/lib";
      OPENSSL_DIR = "${pkgs.openssl.dev}";
    };

    activation.ensureFcitxPinyinDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      mkdir -p "${homeDir}/.local/share/fcitx5/pinyin"
    '';
  };

  home.file.".wayland-session" = {
    source = waylandSession;
    executable = true;
  };
}
