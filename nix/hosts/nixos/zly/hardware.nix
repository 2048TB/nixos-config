args@{ mylib, ... }:
(mylib.mkNixosHardwareModule {
  extraImports = [
    ../_shared/hardware-workarounds-common.nix
    ./hardware-gpu-hybrid.nix
    ./ml-stack.nix
  ];
}) args
