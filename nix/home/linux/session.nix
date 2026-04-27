{ config, pkgs, lib, myvars, osConfig ? null, ... }:
let
  hostCfg = import ../base/resolve-host.nix { inherit myvars osConfig; };
  hasDesktopSession = hostCfg.desktopSession or false;
  homeDir = config.home.homeDirectory;
  rmExe = lib.getExe' pkgs.coreutils "rm";
in
{
  home = lib.mkIf hasDesktopSession {
    # 会话变量（仅 Linux 特有：Wayland/输入法）
    sessionVariables =
      {
        # Wayland 支持
        # 在分数缩放（如 1.25）下，优先让 Chromium/Electron 应用走原生 Wayland，
        # 避免落到 XWayland 后出现字体发虚。
        NIXOS_OZONE_WL = "1";
        QT_QPA_PLATFORMTHEME = "qt6ct";
        # 输入法环境变量
        # waylandFrontend = true 下，NixOS module 已在系统层设置 XMODIFIERS。
        # Gtk3/4 原生 Wayland 应用通过 text-input-v3 协议直接与 Fcitx5 通信，
        # 不再需要 GTK_IM_MODULE（fcitx5 官方 Wayland 文档推荐）。
        # Qt < 6.7 仍需 QT_IM_MODULE；SDL2 文字输入需 SDL_IM_MODULE。
        QT_IM_MODULE = "fcitx";
        SDL_IM_MODULE = "fcitx";
      };

    # Rime 会缓存编译后的 build 产物；配置更新后若不清理，fcitx5 可能继续吃旧配置。
    # 这里只删除 build，等待下次 fcitx5 启动或手动 reload 时自动重建。
    activation.clearFcitxRimeBuild = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -d "${homeDir}/.local/share/fcitx5/rime/build" ]; then
        ${rmExe} -rf "${homeDir}/.local/share/fcitx5/rime/build"
      fi
    '';
  };
}
