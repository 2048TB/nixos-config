{
  inputs,
  lib,
  vars,
  host,
  platform,
  ...
}:
let
  roleDir = ./roles;
  roleModulePath = role: ./roles + "/${role}.nix";
  requestedRoles = vars.roles or [ ];
  supportedRoles =
    if builtins.pathExists roleDir then
      builtins.map (file: lib.removeSuffix ".nix" file) (
        builtins.filter (file: builtins.match ".*\\.nix" file != null) (
          builtins.attrNames (builtins.readDir roleDir)
        )
      )
    else
      [ ];
  unknownRoles = builtins.filter (role: !(builtins.elem role supportedRoles)) requestedRoles;
  roleModules = builtins.filter builtins.pathExists (map roleModulePath requestedRoles);
in
{
  assertions = [
    {
      assertion = unknownRoles == [ ];
      message =
        "Unknown Darwin roles for host `${host}`: "
        + lib.concatStringsSep ", " unknownRoles
        + ". Supported roles: "
        + lib.concatStringsSep ", " supportedRoles;
    }
  ];

  imports = [
    ../shared/host-validation.nix
    inputs.sops-nix.darwinModules.sops
    inputs.home-manager.darwinModules.home-manager
    ./secrets.nix
  ]
  ++ roleModules;

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      options = "--delete-older-than 14d";
    };
  };

  networking.hostName = vars.hostName or host;

  users.users.${vars.username}.home = "/Users/${vars.username}";

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit
        inputs
        vars
        host
        platform
        ;
      inherit (vars) username;
    };
    users.${vars.username} = import ../home/base.nix;
  };

  system = {
    primaryUser = vars.username;
    defaults.NSGlobalDomain.AppleICUForce24HourTime = true;
    stateVersion = 6;
  };
}
