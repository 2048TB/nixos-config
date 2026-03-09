_:
let
  hostMetaSchema = {
    defaultRoles = [ "desktop" ];
    defaultDockerMode = "rootless";

    allowedCpuVendors = [
      "auto"
      "amd"
      "intel"
    ];

    allowedGpuModes = [
      "auto"
      "none"
      "amd"
      "amdgpu"
      "nvidia"
      "modesetting"
      "amd-nvidia-hybrid"
    ];

    allowedDockerModes = [
      "rootless"
      "rootful"
    ];

    knownHostRoles = [
      "desktop"
      "gaming"
      "vpn"
      "virt"
      "container"
    ];

    optionalBoolOptions = [
      "enableHibernate"
      "enableNvidiaContainerToolkit"
      "acceptFlakeConfig"
      "enableProvider appVpn"
      "enableLibvirtd"
      "enableDocker"
      "enableFlatpak"
      "enableSteam"
      "enableWpsOffice"
      "enableZathura"
      "enableSplayer"
      "enableTelegramDesktop"
      "enableLocalSend"
    ];

    optionalStringOptions = [
      "rootTmpfsSize"
      "gcRetentionDays"
      "diskDevice"
    ];

    optionalNullableStringOptions = [
      "amdgpuBusId"
      "nvidiaBusId"
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
      boolFlag = name: fallback:
        if builtins.hasAttr name host then host.${name} else fallback;
    in
    {
      inherit hostRoles hasRole dockerMode;
      enableProvider appVpn = boolFlag "enableProvider appVpn" (hasRole "vpn");
      enableLibvirtd = boolFlag "enableLibvirtd" (hasRole "virt");
      enableDocker = boolFlag "enableDocker" (hasRole "container");
      enableFlatpak = boolFlag "enableFlatpak" (hasRole "desktop");
      enableSteam = boolFlag "enableSteam" (hasRole "gaming");
      useRootfulDocker = dockerMode == "rootful";
      useRootlessDocker = dockerMode == "rootless";
    };
}
