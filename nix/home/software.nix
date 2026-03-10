{
  lib,
  pkgs,
  vars,
  ...
}:
let
  homeSoftware = vars.homeSoftware or { };

  groups = {
    cli = with pkgs; [
      bat
      eza
      fd
      jq
      ripgrep
      tree
      unzip
      zip
    ];

    dev = with pkgs; [
      direnv
    ];

    desktopCore = with pkgs; [
      app2unit
      brightnessctl
      cliphist
      file-roller
      fuzzel
      ghostty
      nautilus
      noctalia-shell
      playerctl
      qt6Packages.qt6ct
      wl-clipboard
    ];

    browser = with pkgs; [
      google-chrome
    ];

    chat = with pkgs; [
      telegram-desktop
    ];

    remote = with pkgs; [
      remmina
    ];

    media = with pkgs; [
      imv
      pavucontrol
      pulsemixer
      zathura
    ];

    archive = with pkgs; [
      p7zip-rar
      unar
      unrar
    ];
  };
  supportedGroups = builtins.attrNames groups;
  unknownGroups = builtins.filter (name: !(builtins.elem name supportedGroups)) (
    builtins.attrNames homeSoftware
  );

  enabledPackages = lib.concatLists (
    lib.mapAttrsToList (name: enabled: lib.optionals enabled (groups.${name} or [ ])) homeSoftware
  );
in
{
  assertions = [
    {
      assertion = unknownGroups == [ ];
      message =
        "Unknown homeSoftware groups: "
        + lib.concatStringsSep ", " unknownGroups
        + ". Supported groups: "
        + lib.concatStringsSep ", " supportedGroups;
    }
  ];

  home.packages = enabledPackages;
}
