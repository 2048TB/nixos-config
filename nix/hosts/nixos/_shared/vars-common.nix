{
  # Identity
  username = "z";
  timezone = "Asia/Shanghai";

  # Storage / Hibernate
  diskDevice =
    let
      envDiskDevice = builtins.getEnv "NIXOS_DISK_DEVICE";
    in
    if envDiskDevice != "" then envDiskDevice else "/dev/nvme0n1";
  swapSizeGb = 32;

  # Default app toggles
  enableWpsOffice = false;
  enableZathura = false;
  enableSplayer = false;
  enableTelegramDesktop = false;
  enableLocalSend = false;
}
