{ inputs, ... }:
let
  self = rec {
    additions = final: _prev: import ../pkgs final;

    modifications = _final: _prev: { };

    unstable-packages =
      final: _prev:
      let
        mylib = import ../lib { lib = final.lib; };
      in
      {
        unstable = import inputs.nixpkgs-unstable {
          inherit (final) system;
          config.allowUnfreePredicate = mylib.allowUnfreePredicate;
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
