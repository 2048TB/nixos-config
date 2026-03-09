args@{ mylib, ... }:
(mylib.mkNixosHardwareModule {
  extraImports = [ ./hardware-workarounds.nix ];
}) args
