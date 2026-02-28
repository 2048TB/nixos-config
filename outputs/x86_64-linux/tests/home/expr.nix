{ lib, nixosConfigurations }:
lib.mapAttrs
  (
    _:
    cfg:
    let
      users = builtins.attrNames cfg.config.home-manager.users;
      user = builtins.head users;
    in
    cfg.config.home-manager.users.${user}.home.homeDirectory
  )
  nixosConfigurations
