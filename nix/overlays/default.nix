{ inputs, ... }:
let
  self = rec {
    additions = final: _prev: import ../pkgs final;

    modifications =
      final: prev:
      {
        antigravity =
          if final.stdenv.hostPlatform.system == "x86_64-linux" then
            final.callPackage ../pkgs/antigravity.nix
              {
                vscode-generic = inputs.nixpkgs + "/pkgs/applications/editors/vscode/generic.nix";
              }
          else
            prev.antigravity;

        vscode =
          if final.stdenv.hostPlatform.system == "x86_64-linux" then
            final.unstable.vscode
          else
            prev.vscode;

        zellij =
          if final.stdenv.hostPlatform.isLinux then
            final.unstable.zellij
          else
            prev.zellij;
      }
      // prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
        kwm-river = inputs."river-kwm".packages.${prev.stdenv.hostPlatform.system}.default;

        river-kwm-session = final.callPackage ../pkgs/river-kwm-session.nix {
          kwm-river = final.kwm-river;
        };
      };

    unstable-packages =
      final: _prev:
      let
        mylib = import ../lib { inherit (final) lib; };
      in
      {
        unstable = import inputs.nixpkgs-unstable {
          inherit (final.stdenv.hostPlatform) system;
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
