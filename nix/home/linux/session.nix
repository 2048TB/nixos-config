{ config
, pkgs
, lib
, myvars
, ...
}:
let
  homeDir = config.home.homeDirectory;
in
{
  home = {
    # 会话变量（仅 Linux 特有：Wayland/输入法/OpenSSL）
    sessionVariables =
      {
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
}
