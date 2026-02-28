{ modulesPath, ... }:
{
  imports = [
    ../default.nix
    (modulesPath + "/installer/scan/not-detected.nix")
    ./hardware.nix
    ./disko.nix
  ];
}
