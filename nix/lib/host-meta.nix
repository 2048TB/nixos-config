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
      "nvidia-prime"
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
      "enableGpuSpecialisation"
      "enableBluetoothRfkillUnblock"
      "enableAggressiveApparmorKill"
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
      "journaldSystemMaxUse"
      "journaldRuntimeMaxUse"
      "gcRetentionDays"
      "diskDevice"
    ];

    optionalNullableStringOptions = [
      "intelBusId"
      "amdgpuBusId"
      "nvidiaBusId"
    ];
  };
in
rec {
  inherit hostMetaSchema;

  roleFlags = myvars:
    let
      hostRoles = myvars.roles or hostMetaSchema.defaultRoles;
      hasRole = role: builtins.elem role hostRoles;
      dockerMode = myvars.dockerMode or hostMetaSchema.defaultDockerMode;
    in
    {
      inherit hostRoles hasRole dockerMode;
      enableProvider appVpn = myvars.enableProvider appVpn or (hasRole "vpn");
      enableLibvirtd = myvars.enableLibvirtd or (hasRole "virt");
      enableDocker = myvars.enableDocker or (hasRole "container");
      enableFlatpak = myvars.enableFlatpak or (hasRole "desktop");
      enableSteam = myvars.enableSteam or (hasRole "gaming");
      useRootfulDocker = dockerMode == "rootful";
      useRootlessDocker = dockerMode == "rootless";
    };
}
