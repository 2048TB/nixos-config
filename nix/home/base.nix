{
  pkgs,
  lib,
  vars,
  host,
  platform ? if pkgs.stdenv.isDarwin then "darwin" else "nixos",
  username ? (vars.username or "z"),
  ...
}:
let
  languageTools = vars.languageTools or [ ];
  roles = vars.roles or [ ];
  supportedLanguageTools = [
    "go"
    "node"
    "rust"
    "python"
  ];
  unknownLanguageTools = builtins.filter (
    tool: !(builtins.elem tool supportedLanguageTools)
  ) languageTools;
  roleModules = [
    ./software.nix
    ./roles/dev-base.nix
  ];
  languageToolModules =
    lib.optionals (builtins.elem "go" languageTools) [ ./roles/go.nix ]
    ++ lib.optionals (builtins.elem "node" languageTools) [ ./roles/node.nix ]
    ++ lib.optionals (builtins.elem "rust" languageTools) [ ./roles/rust.nix ]
    ++ lib.optionals (builtins.elem "python" languageTools) [ ./roles/python.nix ];
  desktopModules = lib.optionals (builtins.elem "desktop" roles) [ ./roles/linux-desktop.nix ];
  hostModule = ../hosts + "/${platform}/${host}/home.nix";
in
{
  assertions = [
    {
      assertion = unknownLanguageTools == [ ];
      message =
        "Unknown Home Manager languageTools for host `${host}`: "
        + lib.concatStringsSep ", " unknownLanguageTools
        + ". Supported languageTools: "
        + lib.concatStringsSep ", " supportedLanguageTools;
    }
  ];

  imports =
    roleModules
    ++ languageToolModules
    ++ desktopModules
    ++ lib.optionals (builtins.pathExists hostModule) [ hostModule ];

  home = {
    inherit username;
    homeDirectory = if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}";
    stateVersion = vars.homeStateVersion or "25.11";
  };

  programs.home-manager.enable = true;
}
