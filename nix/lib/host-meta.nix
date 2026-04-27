_:
let
  hostMetaSchema = {
    defaultRoles = [ ];
    defaultDockerMode = "rootless";
    defaultConfigRepoPath = "/persistent/nixos-config";
    defaultAria2RpcSecretPath = "/run/secrets/services/aria2-rpc";

    allowedGpuModes = [
      "none"
      "amdgpu"
      "nvidia"
      "modesetting"
      "amd-nvidia-hybrid"
    ];

    allowedDockerModes = [
      "rootless"
      "rootful"
    ];

    allowedKinds = [
      "workstation"
      "server"
      "vm"
    ];

    allowedFormFactors = [
      "desktop"
      "laptop"
      "handheld"
      "headless"
    ];

    allowedGpuVendors = [
      "amd"
      "intel"
      "nvidia"
    ];

    allowedDesktopProfiles = [
      "none"
      "niri"
      "aqua"
    ];

    allowedLinuxDesktopProfiles = [
      "none"
      "niri"
    ];

    allowedDarwinDesktopProfiles = [
      "none"
      "aqua"
    ];

    allowedHostTags = [
      "fingerprint-reader"
      "docked"
    ];

    knownHostRoles = [
      "gaming"
      "vpn"
      "virt"
      "container"
    ];

    optionalStringOptions = [
      "diskDevice"
      "luksName"
    ];

    optionalNullableStringOptions = [
      "amdgpuBusId"
      "nvidiaBusId"
    ];

    registryOwnedKeys = [
      "system"
      "desktopSession"
      "desktopProfile"
      "kind"
      "formFactor"
      "tags"
      "gpuVendors"
      "displays"
    ];

    requiredRegistryKeys = [
      "system"
      "desktopSession"
      "desktopProfile"
      "kind"
      "formFactor"
      "tags"
      "gpuVendors"
      "displays"
    ];
  };
in
rec {
  inherit hostMetaSchema;

  roleFlags = host:
    let
      hostRoles = host.roles or hostMetaSchema.defaultRoles;
      hasRole = role: builtins.elem role hostRoles;
      dockerMode = host.dockerMode or hostMetaSchema.defaultDockerMode;
    in
    {
      inherit hostRoles hasRole dockerMode;
      enableMullvadVpn = hasRole "vpn";
      enableLibvirtd = hasRole "virt";
      enableDocker = hasRole "container";
      enableSteam = hasRole "gaming";
      useRootfulDocker = dockerMode == "rootful";
      useRootlessDocker = dockerMode == "rootless";
    };
}
