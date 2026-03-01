rec {
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

  # Roles
  roles = [
    "desktop"
    "gaming"
    "vpn"
    "virt"
    "container"
  ];

  # Credentials
  userPasswordHash = "$6$pV3IR/1syWYqkNhu$wj.dgh8e7jm5eWRfTR/vKVyfqt3BjB1hHJv2tJlF1QlDxfGx89F2JzNm6pjZDsEzLlHwADQ28L9s.I5nqTn5u0";
  rootPasswordHash = "$6$E/rV.FZzRgxXAd4D$etON6WzH7IVVJDwcfOCCKwVsBtrGpsaNEBDMG8zj75mtziDDikfEZqgIo5kGvg70zozIby2zzGjJYjeG8Y0Bu1";
}
