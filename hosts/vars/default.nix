rec {
  # 用户配置
  username = "z";
  hostname = "zly";

  # 系统配置
  timezone = "Asia/Shanghai";

  # 存储配置
  # 默认目标盘（可通过环境变量 NIXOS_DISK_DEVICE 在安装时临时覆盖）
  diskDevice =
    let
      envDiskDevice = builtins.getEnv "NIXOS_DISK_DEVICE";
    in
    if envDiskDevice != "" then envDiskDevice else "/dev/nvme0n1";
  swapSizeGb = 32;
  # hibernate 恢复偏移（swapfile 场景）。
  # 用 root 执行：btrfs inspect-internal map-swapfile -r /swap/swapfile
  resumeOffset = 7709952;

  # GPU 固定配置（不再依赖文件/环境变量）
  gpuMode = "amd-nvidia-hybrid";
  enableGpuSpecialisation = false;

  # 账户密码（SHA-512 哈希，使用 mkpasswd -m sha-512 生成）
  userPasswordHash = "$6$pV3IR/1syWYqkNhu$wj.dgh8e7jm5eWRfTR/vKVyfqt3BjB1hHJv2tJlF1QlDxfGx89F2JzNm6pjZDsEzLlHwADQ28L9s.I5nqTn5u0";
  rootPasswordHash = "$6$E/rV.FZzRgxXAd4D$etON6WzH7IVVJDwcfOCCKwVsBtrGpsaNEBDMG8zj75mtziDDikfEZqgIo5kGvg70zozIby2zzGjJYjeG8Y0Bu1";
}
