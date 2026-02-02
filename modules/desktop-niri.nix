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
}
