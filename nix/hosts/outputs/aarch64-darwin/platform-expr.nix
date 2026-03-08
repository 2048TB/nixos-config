{ lib, darwinConfigurations }:
lib.mapAttrs (_: cfg: cfg.pkgs.stdenv.hostPlatform.system) darwinConfigurations
