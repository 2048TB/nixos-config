{ config, vars, ... }:
let
  commonSopsFile = ../../../secrets/common.yaml;
in
{
  sops.secrets."password_root_hash" = {
    neededForUsers = true;
    key = "password_root_hash";
    sopsFile = commonSopsFile;
  };

  sops.secrets."password_${vars.username}_hash" = {
    neededForUsers = true;
    key = "password_${vars.username}_hash";
    sopsFile = commonSopsFile;
  };

  users = {
    mutableUsers = false;
    users.root.hashedPasswordFile = config.sops.secrets."password_root_hash".path;
    users.${vars.username}.hashedPasswordFile =
      config.sops.secrets."password_${vars.username}_hash".path;
  };
}
