args@{ mylib, ... }:
(mylib.mkNixosHardwareModule {
  extraImports = [
    ./hardware-workarounds.nix
    ./hardware-gpu-hybrid.nix
  ];
}) args
