{ lib, config, myvars, mylib, ... }:
let
  inherit (lib) types;
  schema = mylib.hostMetaSchema;
  defaultRoles = myvars.roles or schema.defaultRoles;
  defaultFormFactor = myvars.formFactor or "desktop";
  defaultProfileList =
    myvars.profiles or (
      (lib.optionals (builtins.elem "desktop" defaultRoles) [ "desktop" ])
      ++ (lib.optionals (defaultFormFactor == "laptop") [ "laptop" ])
      ++ (lib.optionals (defaultFormFactor == "server") [ "server" ])
    );
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

      configRepoPath = lib.mkOption {
        type = types.str;
        default = myvars.configRepoPath or "/persistent/nixos-config";
        description = "Persistent repository path on target system.";
      };

      diskDevice = lib.mkOption {
        type = types.str;
        default = myvars.diskDevice or "/dev/nvme0n1";
        description = "Primary installation disk device.";
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

      cpuVendor = lib.mkOption {
        type = types.enum schema.allowedCpuVendors;
        default = myvars.cpuVendor or "auto";
        description = "CPU vendor selector for KVM modules.";
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

      formFactor = lib.mkOption {
        type = types.enum [ "desktop" "laptop" "server" ];
        default = defaultFormFactor;
        description = "Physical/logical form factor.";
      };

      extraTrustedUsers = lib.mkOption {
        type = types.listOf types.str;
        default = myvars.extraTrustedUsers or [ ];
        description = "Extra trusted users for nix settings.";
      };

      rootTmpfsSize = lib.mkOption {
        type = types.str;
        default = myvars.rootTmpfsSize or "2G";
        description = "tmpfs size for root filesystem.";
      };

      journaldSystemMaxUse = lib.mkOption {
        type = types.str;
        default = myvars.journaldSystemMaxUse or "512M";
        description = "journald SystemMaxUse.";
      };

      journaldRuntimeMaxUse = lib.mkOption {
        type = types.str;
        default = myvars.journaldRuntimeMaxUse or "256M";
        description = "journald RuntimeMaxUse.";
      };

      gcRetentionDays = lib.mkOption {
        type = types.str;
        default = myvars.gcRetentionDays or "14d";
        description = "Nix GC retention period.";
      };

      intelBusId = lib.mkOption {
        type = types.nullOr types.str;
        default = myvars.intelBusId or null;
        description = "Intel iGPU bus id for PRIME.";
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

      enableHibernate = lib.mkOption {
        type = types.bool;
        default = myvars.enableHibernate or true;
        description = "Enable hibernate-related boot/storage logic.";
      };

      enableGpuSpecialisation = lib.mkOption {
        type = types.bool;
        default = myvars.enableGpuSpecialisation or false;
        description = "Enable GPU specialisation boot entries.";
      };

      enableBluetoothRfkillUnblock = lib.mkOption {
        type = types.bool;
        default = myvars.enableBluetoothRfkillUnblock or false;
        description = "Run rfkill unblock helper at boot.";
      };

      enableAggressiveApparmorKill = lib.mkOption {
        type = types.bool;
        default = myvars.enableAggressiveApparmorKill or false;
        description = "Enable killUnconfinedConfinables for AppArmor.";
      };

      enableNvidiaContainerToolkit = lib.mkOption {
        type = types.bool;
        default = myvars.enableNvidiaContainerToolkit or false;
        description = "Enable nvidia-container-toolkit.";
      };

      acceptFlakeConfig = lib.mkOption {
        type = types.bool;
        default = myvars.acceptFlakeConfig or false;
        description = "Whether to accept flake-provided nixConfig values.";
      };

      enableProvider appVpn = lib.mkOption {
        type = types.bool;
        default = myvars.enableProvider appVpn or (builtins.elem "vpn" defaultRoles);
        description = "Explicit Provider app toggle.";
      };

      enableLibvirtd = lib.mkOption {
        type = types.bool;
        default = myvars.enableLibvirtd or (builtins.elem "virt" defaultRoles);
        description = "Explicit libvirtd toggle.";
      };

      enableDocker = lib.mkOption {
        type = types.bool;
        default = myvars.enableDocker or (builtins.elem "container" defaultRoles);
        description = "Explicit Docker toggle.";
      };

      enableFlatpak = lib.mkOption {
        type = types.bool;
        default = myvars.enableFlatpak or (builtins.elem "desktop" defaultRoles);
        description = "Explicit Flatpak toggle.";
      };

      enableSteam = lib.mkOption {
        type = types.bool;
        default = myvars.enableSteam or (builtins.elem "gaming" defaultRoles);
        description = "Explicit Steam toggle.";
      };

      enableWpsOffice = lib.mkOption {
        type = types.bool;
        default = myvars.enableWpsOffice or false;
        description = "Enable WPS Office package.";
      };

      enableZathura = lib.mkOption {
        type = types.bool;
        default = myvars.enableZathura or false;
        description = "Enable Zathura package.";
      };

      enableSplayer = lib.mkOption {
        type = types.bool;
        default = myvars.enableSplayer or false;
        description = "Enable Splayer package.";
      };

      enableTelegramDesktop = lib.mkOption {
        type = types.bool;
        default = myvars.enableTelegramDesktop or false;
        description = "Enable Telegram Desktop package.";
      };

      enableLocalSend = lib.mkOption {
        type = types.bool;
        default = myvars.enableLocalSend or false;
        description = "Enable LocalSend package.";
      };

      deployHost = lib.mkOption {
        type = types.str;
        default = myvars.deployHost or (myvars.hostname or "");
        description = "Remote deploy target host/IP.";
      };

      deployUser = lib.mkOption {
        type = types.str;
        default = myvars.deployUser or "root";
        description = "Remote deploy SSH user.";
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
