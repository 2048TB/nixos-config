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

  # Shared local RPC secret for aria2 browser integration.
  aria2RpcSecret = "1fa5f6a8cda243009f24737c6d0307c4c9ab8829772ad9a441cbac3c277b5c60";
}
