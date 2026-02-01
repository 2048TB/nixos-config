{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # GUI 应用
    google-chrome
    vscode
    remmina
    virt-manager
    virt-viewer
    spice-gtk
    nomacs

    # Wayland 工具
    satty
    swayidle
    mako
    grim
    slurp
    wl-screenrec

    # 基础工具
    file-roller
    zathura
    gnome-text-editor
  ];
}
