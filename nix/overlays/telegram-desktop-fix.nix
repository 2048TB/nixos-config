final: prev:
let
  lib = prev.lib;
in
{
  telegram-desktop = prev.telegram-desktop.override {
    unwrapped = prev.telegram-desktop.unwrapped.overrideAttrs (old: {
      buildInputs = (old.buildInputs or [ ]) ++ [ final.libzip ];
      NIX_CFLAGS_COMPILE = lib.concatStringsSep " " (
        lib.filter (flag: flag != "") [
          (old.NIX_CFLAGS_COMPILE or "")
          "-Wno-error=sign-conversion"
        ]
      );
    });
  };
}
