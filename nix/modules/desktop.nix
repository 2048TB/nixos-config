{ pkgs, mainUser, ... }:
{
  services.xserver.enable = false;
  programs.niri.enable = true;

  services.greetd = {
    enable = true;
    settings.default_session = {
      user = mainUser;
      command = "/home/${mainUser}/.wayland-session";
    };
  };

  # Wayland 桌面常用的 portal（文件选择/截图/投屏）
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    config.common.default = [
      "gtk"
      "gnome"
    ];
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
    ];
  };

  fonts.packages = with pkgs; [
    # 编程字体
    maple-mono.NF-CN-unhinted # Nerd Font with Chinese glyphs

    # CJK 字体（已优化：移除 source-han 重复，仅保留 Noto）
    # 说明：source-han-sans 和 noto-fonts-cjk-sans 是同一套字体的不同品牌
    noto-fonts-cjk-sans # CJK 黑体（中日韩）
    noto-fonts-cjk-serif # CJK 宋体（中日韩）

    # 备用中文字体
    wqy_zenhei # 文泉驿正黑（轻量级，约 10MB）

    # 优化效果：移除 source-han-sans/serif 节省约 800MB
  ];

  # 输入法与中文支持
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      qt6Packages.fcitx5-configtool
      fcitx5-gtk
      (fcitx5-rime.override { rimeDataPkgs = [ rime-data ]; })
      qt6Packages.fcitx5-chinese-addons  # 中文拼音输入法
    ];
  };

  # 音频（含 32 位支持，便于 Steam/Proton）
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Thunar 文件管理与缩略图/挂载支持
  services.gvfs.enable = true;
  services.tumbler.enable = true;
  programs.thunar = {
    enable = true;
    plugins = with pkgs; [
      thunar-archive-plugin
      thunar-volman
    ];
  };

  # GNOME Keyring
  services.gnome.gnome-keyring.enable = true;
  programs.seahorse.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;
}
