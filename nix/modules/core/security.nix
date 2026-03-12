_:
{
  security = {
    apparmor.enable = true;

    polkit = {
      enable = true;
    };
    rtkit.enable = true;
    pam.services.greetd.enableGnomeKeyring = true;
  };
}
