let
  common = import ../_shared/vars-common.nix;
in
common // {
  # zly 独立主机变量（保持与 zky 同结构，便于对比与后续分化）
  systemStateVersion = "25.11";
  homeStateVersion = "25.11";
  timezone = "America/Vancouver";
  locale = "en_CA.UTF-8";

  # Storage / Hibernate
  resumeOffset = 7182282;

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
