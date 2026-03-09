{
  # zzly 独立主机变量（保持与 zly 同结构，便于对比与后续分化）

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

  resumeOffset = 1513128;

  # Hardware
  cpuVendor = "amd";
  gpuMode = "amd";

  # Roles
  roles = [
    "desktop"
    "vpn"
  ];

  # App toggles (zzly)
  enableWpsOffice = false;
  enableZathura = false;
  enableSplayer = false;
  enableTelegramDesktop = false;
  enableLocalSend = false;

  # Credentials are managed by sops secrets:
  # - secrets/passwords/user-password.yaml
  # - secrets/passwords/root-password.yaml
}
