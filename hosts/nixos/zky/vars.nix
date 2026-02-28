rec {
  # 每台 NixOS 主机使用完整 vars；services 默认由 roles 驱动。
  username = "z";
  timezone = "Asia/Shanghai";

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

  gpuMode = "amd";
  enableGpuSpecialisation = false;
  enableBluetoothRfkillUnblock = false;

  roles = [
    "desktop"
    "gaming"
    "vpn"
    "virt"
    "container"
  ];

  userPasswordHash = "$6$pV3IR/1syWYqkNhu$wj.dgh8e7jm5eWRfTR/vKVyfqt3BjB1hHJv2tJlF1QlDxfGx89F2JzNm6pjZDsEzLlHwADQ28L9s.I5nqTn5u0";
  rootPasswordHash = "$6$E/rV.FZzRgxXAd4D$etON6WzH7IVVJDwcfOCCKwVsBtrGpsaNEBDMG8zj75mtziDDikfEZqgIo5kGvg70zozIby2zzGjJYjeG8Y0Bu1";
}
