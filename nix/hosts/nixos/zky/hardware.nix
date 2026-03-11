args@{ mylib, ... }:
(mylib.mkNixosHardwareModule {
  extraImports = [ ../_shared/hardware-workarounds-common.nix ];
}) args
