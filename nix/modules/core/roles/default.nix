{ ... }:
{
  imports = [
    ./firewall.nix
    ./steam.nix
    ./provider-app.nix
    ./flatpak.nix
    ./libvirtd.nix
    ./docker.nix
  ];
}
