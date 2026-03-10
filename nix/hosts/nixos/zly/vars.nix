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

  resumeOffset = 10113490;

  # Hardware
  gpuMode = "amd-nvidia-hybrid";
  # Hybrid GPU Bus IDs for PRIME.
  # Official NixOS form is `PCI:<bus>@<domain>:<device>:<function>` and uses decimal numbers.
  # Example: lspci `0000:01:00.0` -> `PCI:1@0:0:0`.
  amdgpuBusId = "PCI:18@0:0:0";
  nvidiaBusId = "PCI:1@0:0:0";
  nvidiaOpen = true;
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
  enableWpsOffice = true;
  enableZathura = true;
  enableSplayer = true;
  enableTelegramDesktop = true;
  enableLocalSend = true;

  # Credentials are managed by sops secrets:
  # - secrets/passwords/user-password.yaml
  # - secrets/passwords/root-password.yaml
}
