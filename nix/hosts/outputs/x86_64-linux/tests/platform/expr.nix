{ lib, nixosConfigurations }:
lib.mapAttrs (_: cfg: cfg.pkgs.stdenv.hostPlatform.system) nixosConfigurations
