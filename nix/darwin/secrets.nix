{
  lib,
  vars,
  host,
  ...
}:
let
  hostSecretModule = ../hosts/darwin + "/${host}/secrets.nix";
  hostSopsFile = ../../secrets/darwin + "/${host}.yaml";
in
{
  _module.args.hostSopsFile = hostSopsFile;

  imports = lib.optionals (builtins.pathExists hostSecretModule) [ hostSecretModule ];

  sops = {
    defaultSopsFormat = "yaml";
    defaultSopsFile = hostSopsFile;
    age.keyFile = lib.mkDefault "/Users/${vars.username}/Library/Application Support/sops/age/keys.txt";
  };
}
