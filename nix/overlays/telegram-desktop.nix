_final: prev: {
  # nixpkgs#497549: telegram-desktop fails to build with minizip headers on current nixpkgs.
  telegram-desktop = prev.telegram-desktop.override {
    unwrapped = prev.telegram-desktop.unwrapped.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ../patches/telegram-desktop-minizip-include.patch ];
    });
  };
}
