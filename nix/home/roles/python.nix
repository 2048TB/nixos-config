{ pkgs, ... }:
{
  home.packages = with pkgs; [
    python3Packages.pip
    python3Packages.virtualenv
  ];
}
