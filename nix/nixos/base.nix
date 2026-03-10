{
  lib,
  pkgs,
  inputs,
  vars,
  host,
  platform,
  ...
}:
let
  requestedRoles = vars.roles or [ ];
  roleModulePath = role: ./roles + "/${role}.nix";
  supportedRoles = builtins.filter (role: role != "secrets") (
    builtins.map (file: lib.removeSuffix ".nix" file) (
      builtins.filter (file: builtins.match ".*\\.nix" file != null) (
        builtins.attrNames (builtins.readDir ./roles)
      )
    )
  );
  unknownRoles = builtins.filter (role: !(builtins.elem role supportedRoles)) requestedRoles;
  roleModules = map roleModulePath requestedRoles;
in
{
  assertions = [
    {
      assertion = unknownRoles == [ ];
      message =
        "Unknown NixOS roles for host `${host}`: "
        + lib.concatStringsSep ", " unknownRoles
        + ". Supported roles: "
        + lib.concatStringsSep ", " supportedRoles;
    }
  ];

  imports = [
    ../shared/host-validation.nix
    inputs.disko.nixosModules.disko
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
    ./roles/resume.nix
    ./roles/secrets.nix
    ./software.nix
  ]
  ++ roleModules;

  nixpkgs.hostPlatform = lib.mkDefault (vars.system or "x86_64-linux");
  nixpkgs.config.allowUnfree = true;

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
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  environment.systemPackages = with pkgs; [
    btrfs-progs
    snapper
  ];

  networking.hostName = vars.hostName or host;
  networking.networkmanager.enable = true;

  time.timeZone = vars.timezone;
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
  services = {
    btrfs.autoScrub.enable = true;
    snapper = {
      cleanupInterval = "daily";
      snapshotInterval = "hourly";
      configs.root = {
        FSTYPE = "btrfs";
        SUBVOLUME = "/";
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        TIMELINE_LIMIT_HOURLY = 12;
        TIMELINE_LIMIT_DAILY = 7;
        TIMELINE_LIMIT_WEEKLY = 4;
        TIMELINE_LIMIT_MONTHLY = 3;
      };
    };
    openssh.enable = true;
  };

  users.users.${vars.username} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;
  programs.nh.enable = true;

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

  system.stateVersion = vars.systemStateVersion;
}
