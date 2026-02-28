{ lib, nixosConfigurations }:
lib.mapAttrs (_: cfg: cfg.config.networking.hostName) nixosConfigurations
