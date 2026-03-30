{ config
, pkgs
, lib
, mainUser
, ...
}:
{
  _module.args.userProfileBin = "/etc/profiles/per-user/${mainUser}/bin";

  imports = [
    ../base
  ] ++ (import ./_mixins { inherit lib; });

  home = {
    enableNixpkgsReleaseCheck = true;
    username = mainUser;
    homeDirectory = "/home/${mainUser}";
  };

  # Cursor theme：Adwaita 已在 closure 中（GTK 应用隐式依赖），不增加额外构建负担。
  # 同时为 GTK 提供完整 cursor name set（hand2、arrow 等），消除加载告警。
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
      font-name = "Sarasa UI SC 11";
      monospace-font-name = "Fira Code 12";
      font-antialiasing = "rgba";
      font-hinting = "slight";
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
