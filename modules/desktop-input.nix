{ pkgs, ... }:
{
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
}
