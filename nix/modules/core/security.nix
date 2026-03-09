{ pkgs
, ...
}:
{
  security = {
    apparmor = {
      enable = true;
      packages = with pkgs; [
        apparmor-utils
        apparmor-profiles
      ];
    };

    polkit = {
      enable = true;
    };
    rtkit.enable = true;
    pam.services.greetd.enableGnomeKeyring = true;
    pam.services.passwd.enableGnomeKeyring = true;
  };
}
