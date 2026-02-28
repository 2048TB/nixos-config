{ lib, darwinConfigurations }:
lib.mapAttrs (_: cfg: cfg.config.networking.hostName) darwinConfigurations
