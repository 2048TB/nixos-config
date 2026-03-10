{ pkgs, ... }:
{
  services = {
    displayManager.sessionPackages = [ pkgs.niri ];

    greetd = {
      enable = true;
      settings.default_session = {
        user = "greeter";
        command = ''
          ${pkgs.tuigreet}/bin/tuigreet \
            --time \
            --remember \
            --cmd ${pkgs.niri}/bin/niri-session
        '';
      };
    };

    dbus.enable = true;
    upower.enable = true;
    power-profiles-daemon.enable = true;

    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };
  };

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    configPackages = [ pkgs.niri ];
    config.niri."org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
  };

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-gtk
      qt6Packages.fcitx5-chinese-addons
    ];
  };

  security.polkit.enable = true;
  security.rtkit.enable = true;
  hardware.bluetooth.enable = true;

  programs.dconf.enable = true;
  programs.niri.enable = true;

  environment.systemPackages = with pkgs; [
    qt5.qtwayland
    qt6.qtwayland
    xwayland-satellite
  ];

  fonts.packages = with pkgs; [
    dejavu_fonts
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
  ];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    QT_QPA_PLATFORM = "wayland;xcb";
    SDL_VIDEODRIVER = "wayland";
    XDG_CURRENT_DESKTOP = "niri";
    XDG_SESSION_DESKTOP = "niri";
    XDG_SESSION_TYPE = "wayland";
  };
}
