{
  # zky 独立主机变量（保持与 zly 同结构，便于对比与后续分化）

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
  resumeOffset = 533760;
  rootTmpfsSize = "2G";
  journaldSystemMaxUse = "512M";
  journaldRuntimeMaxUse = "256M";

  # Hardware
  gpuMode = "amd";
  enableGpuSpecialisation = false;
  enableBluetoothRfkillUnblock = false;
  enableAggressiveApparmorKill = false;
  dockerMode = "rootless";

  # Roles
  roles = [
    "desktop"
    "vpn"
  ];

  # App toggles (zky)
  enableWpsOffice = false;
  enableZathura = false;
  enableSplayer = false;
  enableTelegramDesktop = false;
  enableLocalSend = false;

  # Credentials are managed by agenix secrets:
  # - secrets/passwords/user-password.age
  # - secrets/passwords/root-password.age
}
