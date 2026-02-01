{ pkgs, ... }:
{
  # 安全加固与桌面所需
  security.polkit.enable = true;
  programs.dconf.enable = true;

  # GnuPG
  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-qt;
    enableSSHSupport = false;
    settings.default-cache-ttl = 4 * 60 * 60;
  };
}
