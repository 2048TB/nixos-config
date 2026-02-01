{ pkgs, myvars, ... }:
{
  services.xserver.enable = false;
  programs.niri.enable = true;

  services.greetd = {
    enable = true;
    settings.default_session = {
      user = myvars.username;
      command = "/home/${myvars.username}/.wayland-session";
    };
  };
}
