{ lib, nixosConfigurations }:
lib.mapAttrs (_: cfg: cfg.config.boot.kernelPackages.kernel.system) nixosConfigurations
