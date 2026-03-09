args@{ mylib, ... }:
(mylib.mkNixosHardwareModule {
  extraImports = [
    ./hardware-gpu-hybrid.nix
  ];
}) args
