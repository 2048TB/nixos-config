{ inputs, ... }:
let
  self = rec {
    additions = final: _prev: import ../pkgs final;

    modifications = _final: _prev: { };

    unstable-packages = final: _prev: {
      unstable = import inputs.nixpkgs-unstable {
        inherit (final) system;
        config.allowUnfree = true;
      };
    };

    default =
      final: prev:
      (additions final prev)
      // (modifications final prev)
      // (unstable-packages final prev);
  };
in
self
