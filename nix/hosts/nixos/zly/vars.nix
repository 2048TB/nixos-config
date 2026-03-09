{
  # zly 独立主机变量（保持与 zky 同结构，便于对比与后续分化）

  # Identity
  username = "z";
  timezone = "Asia/Shanghai";
  systemStateVersion = "25.11";
  homeStateVersion = "25.11";

  # Storage / Hibernate
  diskDevice =
    let
      envDiskDevice = builtins.getEnv "NIXOS_DISK_DEVICE";
    in
    if envDiskDevice != "" then envDiskDevice else "/dev/nvme0n1";
  swapSizeGb = 32;

  enableHibernate = true;
  resumeOffset = 7709952;
  rootTmpfsSize = "2G";
  journaldSystemMaxUse = "512M";
  journaldRuntimeMaxUse = "256M";

  # Hardware
  cpuVendor = "amd";
  gpuMode = "amd-nvidia-hybrid";
  # Hybrid GPU Bus IDs (set from `lspci -D`; format: PCI:<bus>:<device>:<function>)
  amdgpuBusId = "PCI:18:0:0";
  nvidiaBusId = "PCI:1:0:0";
  dockerMode = "rootless";

  # Roles
  roles = [
    "desktop"
    "gaming"
    "vpn"
    "virt"
    "container"
  ];

  # App toggles (zly)
  enableWpsOffice = false;
  enableZathura = true;
  enableSplayer = true;
  enableTelegramDesktop = false;
  enableLocalSend = true;

  # Credentials are managed by sops secrets:
  # - secrets/passwords/user-password.yaml
  # - secrets/passwords/root-password.yaml
}
