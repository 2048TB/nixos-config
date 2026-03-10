{ lib, host, ... }:
let
  hostSecretModule = ../../hosts/nixos + "/${host}/secrets.nix";
  hostSopsFile = ../../../secrets/nixos + "/${host}.yaml";
in
{
  _module.args.hostSopsFile = hostSopsFile;

  imports = [
    ../secrets/shared.nix
  ]
  ++ lib.optionals (builtins.pathExists hostSecretModule) [ hostSecretModule ];

  sops = {
    defaultSopsFormat = "yaml";
    age = {
      sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      keyFile = lib.mkDefault "/var/lib/sops-nix/key.txt";
    };
    defaultSopsFile = ../../../secrets/common.yaml;
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/sops-nix 0700 root root -"
  ];
}
