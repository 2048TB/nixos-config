{ pkgs, ... }:
{
  home.packages = with pkgs; [
    clippy
    rustfmt
  ];
}
