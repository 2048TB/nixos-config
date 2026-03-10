{
  lib,
  pkgs,
  vars,
  ...
}:
let
  software = vars.software or { };
  supportedSoftwareKeys = [
    "virtManager"
    "virtViewer"
    "dive"
    "lazydocker"
    "dockerCompose"
  ];
  unknownSoftwareKeys = builtins.filter (name: !(builtins.elem name supportedSoftwareKeys)) (
    builtins.attrNames software
  );
  packages =
    lib.optionals (software.virtViewer or false) [ pkgs.virt-viewer ]
    ++ lib.optionals (software.dive or false) [ pkgs.dive ]
    ++ lib.optionals (software.lazydocker or false) [ pkgs.lazydocker ]
    ++ lib.optionals (software.dockerCompose or false) [ pkgs.docker-compose ];
in
{
  assertions = [
    {
      assertion = unknownSoftwareKeys == [ ];
      message =
        "Unknown system software keys: "
        + lib.concatStringsSep ", " unknownSoftwareKeys
        + ". Supported keys: "
        + lib.concatStringsSep ", " supportedSoftwareKeys;
    }
  ];

  programs.virt-manager.enable = software.virtManager or false;

  environment.systemPackages = packages;
}
