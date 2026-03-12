_:
{
  security = {
    apparmor.enable = true;

    polkit = {
      enable = true;
    };
    rtkit.enable = true;
  };
}
