{ lib, config, myvars, mylib, ... }:
let
  inherit (lib) types;
  schema = mylib.hostMetaSchema;
  defaultRoles = myvars.roles or schema.defaultRoles;
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

      kind = lib.mkOption {
        type = types.enum schema.allowedKinds;
        default = myvars.kind or "workstation";
        description = "High-level host kind.";
      };

      formFactor = lib.mkOption {
        type = types.enum schema.allowedFormFactors;
        default = myvars.formFactor or "desktop";
        description = "Physical host form factor.";
      };

      tags = lib.mkOption {
        type = types.listOf (types.enum schema.allowedHostTags);
        default = myvars.tags or [ ];
        description = "Canonical host tags sourced from the registry.";
      };

      desktopSession = lib.mkOption {
        type = types.bool;
        default = myvars.desktopSession or false;
        description = "Whether this host should load the desktop session stack.";
      };

      desktopProfile = lib.mkOption {
        type = types.enum schema.allowedDesktopProfiles;
        default = myvars.desktopProfile or "none";
        description = "Desktop profile sourced from the registry.";
      };

      gpuVendors = lib.mkOption {
        type = types.listOf (types.enum schema.allowedGpuVendors);
        default = myvars.gpuVendors or [ ];
        description = "GPU vendors declared for this host.";
      };

      displays = lib.mkOption {
        type = types.listOf (
          types.submodule (_: {
            options = {
              name = lib.mkOption {
                type = types.str;
                description = "Logical display name.";
              };
              match = lib.mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Optional compositor-specific stable output match string.";
              };
              width = lib.mkOption {
                type = types.nullOr types.ints.positive;
                default = null;
                description = "Optional display width in pixels.";
              };
              height = lib.mkOption {
                type = types.nullOr types.ints.positive;
                default = null;
                description = "Optional display height in pixels.";
              };
              refresh = lib.mkOption {
                type = types.nullOr types.number;
                default = null;
                description = "Optional refresh rate in Hz.";
              };
              scale = lib.mkOption {
                type = types.nullOr types.number;
                default = null;
                description = "Optional UI scale factor.";
              };
              primary = lib.mkOption {
                type = types.bool;
                default = false;
                description = "Whether this display is the primary output.";
              };
              workspaceSet = lib.mkOption {
                type = types.listOf types.ints.positive;
                default = [ ];
                description = "Optional workspace hints associated with the display.";
              };
            };
          })
        );
        default = myvars.displays or [ ];
        description = "Display topology metadata sourced from the registry.";
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
        default = myvars.gpuMode or "modesetting";
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

    capabilities = {
      isWorkstation = lib.mkOption {
        type = types.bool;
        readOnly = true;
        description = "Derived flag for workstation hosts.";
      };

      isServer = lib.mkOption {
        type = types.bool;
        readOnly = true;
        description = "Derived flag for server hosts.";
      };

      isVm = lib.mkOption {
        type = types.bool;
        readOnly = true;
        description = "Derived flag for virtual machine hosts.";
      };

      isDesktop = lib.mkOption {
        type = types.bool;
        readOnly = true;
        description = "Derived flag for desktop form factor.";
      };

      isLaptop = lib.mkOption {
        type = types.bool;
        readOnly = true;
        description = "Derived flag for laptop form factor.";
      };

      hasDesktopSession = lib.mkOption {
        type = types.bool;
        readOnly = true;
        description = "Derived flag for hosts that should load the desktop session stack.";
      };

      usesRiver = lib.mkOption {
        type = types.bool;
        readOnly = true;
        description = "Derived flag for hosts using the River desktop profile.";
      };

      hasMultipleDisplays = lib.mkOption {
        type = types.bool;
        readOnly = true;
        description = "Derived flag for hosts with multiple declared displays.";
      };

      hasDisplayTopology = lib.mkOption {
        type = types.bool;
        readOnly = true;
        description = "Derived flag for hosts with declared display topology metadata.";
      };

      hasHiDpiDisplay = lib.mkOption {
        type = types.bool;
        readOnly = true;
        description = "Derived flag for hosts with a HiDPI display.";
      };

      primaryDisplayName = lib.mkOption {
        type = types.nullOr types.str;
        readOnly = true;
        description = "Derived primary display name from host display metadata.";
      };

      hasFingerprintReader = lib.mkOption {
        type = types.bool;
        readOnly = true;
        description = "Derived flag for hosts tagged with a fingerprint reader.";
      };

      hasAmdGpu = lib.mkOption {
        type = types.bool;
        readOnly = true;
        description = "Derived flag for AMD GPU presence.";
      };

      hasIntelGpu = lib.mkOption {
        type = types.bool;
        readOnly = true;
        description = "Derived flag for Intel GPU presence.";
      };

      hasNvidiaGpu = lib.mkOption {
        type = types.bool;
        readOnly = true;
        description = "Derived flag for NVIDIA GPU presence.";
      };
    };
  };

  config = {
    my.capabilities = mylib.deriveHostCapabilities config.my.host;
  };
}
