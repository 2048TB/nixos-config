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
  enableGpuSpecialisation = false;
  enableBluetoothRfkillUnblock = true;
  enableAggressiveApparmorKill = false;
  dockerMode = "rootless";
  enableWaybarBacklight = false;
  enableWaybarBattery = false;

  # Roles
  roles = [
    "desktop"
    "gaming"
    "vpn"
    "virt"
    "container"
  ];

  # App toggles (zly)
  enableWpsOffice = true;
  enableZathura = true;
  enableSplayer = true;
  enableTelegramDesktop = true;
  enableLocalSend = true;

  # Credentials are managed by agenix secrets:
  # - secrets/passwords/user-password.age
  # - secrets/passwords/root-password.age
}
