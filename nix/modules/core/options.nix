{ lib, config, myvars, mylib, ... }:
let
  inherit (lib) types;
  schema = mylib.hostMetaSchema;
  defaultRoles = myvars.roles or schema.defaultRoles;
  defaultProfileList = myvars.profiles or [ ];
  hasProfile = profile: builtins.elem profile defaultProfileList;
in
{
  options.my = {
    host = {
      hostname = lib.mkOption {
        type = types.str;
        default = myvars.hostname or "";
        description = "Canonical hostname for this host.";
      };

      username = lib.mkOption {
        type = types.str;
        default = myvars.username or "";
        description = "Primary user managed by this host.";
      };

      timezone = lib.mkOption {
        type = types.str;
        default = myvars.timezone or "UTC";
        description = "System timezone.";
      };

      systemStateVersion = lib.mkOption {
        type = types.str;
        default = myvars.systemStateVersion or "25.11";
        description = "NixOS system.stateVersion.";
      };

      homeStateVersion = lib.mkOption {
        type = types.str;
        default = myvars.homeStateVersion or "25.11";
        description = "Home Manager stateVersion.";
      };

      diskDevice = lib.mkOption {
        type = types.str;
        default = myvars.diskDevice or "/dev/nvme0n1";
        description = "Primary installation disk device.";
      };

      luksName = lib.mkOption {
        type = types.str;
        default = myvars.luksName or "crypted-nixos";
        description = "LUKS mapper name used by disko, swap, and resume wiring.";
      };

      swapSizeGb = lib.mkOption {
        type = types.ints.positive;
        default = myvars.swapSizeGb or 16;
        description = "Swapfile size in GiB.";
      };

      resumeOffset = lib.mkOption {
        type = types.nullOr types.ints.positive;
        default = myvars.resumeOffset or null;
        description = "Btrfs swapfile resume offset for hibernate.";
      };

      gpuMode = lib.mkOption {
        type = types.enum schema.allowedGpuModes;
        default = myvars.gpuMode or "auto";
        description = "GPU mode selector.";
      };

      dockerMode = lib.mkOption {
        type = types.enum schema.allowedDockerModes;
        default = myvars.dockerMode or schema.defaultDockerMode;
        description = "Docker engine mode.";
      };

      roles = lib.mkOption {
        type = types.listOf (types.enum schema.knownHostRoles);
        default = defaultRoles;
        description = "Host roles for feature toggles.";
      };

      profiles = lib.mkOption {
        type = types.listOf (types.enum [ "desktop" "laptop" "server" ]);
        default = defaultProfileList;
        description = "High-level host profiles.";
      };

      amdgpuBusId = lib.mkOption {
        type = types.nullOr types.str;
        default = myvars.amdgpuBusId or null;
        description = "AMD GPU bus id for PRIME.";
      };

      nvidiaBusId = lib.mkOption {
        type = types.nullOr types.str;
        default = myvars.nvidiaBusId or null;
        description = "NVIDIA GPU bus id for PRIME.";
      };

      nvidiaOpen = lib.mkOption {
        type = types.nullOr types.bool;
        default = myvars.nvidiaOpen or null;
        description = "Override hardware.nvidia.open when a host requires proprietary-only kernel modules.";
      };

    };

    profiles = {
      desktop = lib.mkOption {
        type = types.bool;
        default = hasProfile "desktop";
        description = "Desktop profile gate.";
      };

      laptop = lib.mkOption {
        type = types.bool;
        default = hasProfile "laptop";
        description = "Laptop profile gate.";
      };

      server = lib.mkOption {
        type = types.bool;
        default = hasProfile "server";
        description = "Server profile gate.";
      };
    };
  };

  config.assertions = [
    {
      assertion = !(config.my.profiles.desktop && config.my.profiles.server);
      message = "my.profiles.desktop and my.profiles.server must not both be true.";
    }
  ];
}
