let
  common = import ../_shared/vars-common.nix;
in
common // {
  # zzly 独立主机变量（保持与 zly 同结构，便于对比与后续分化）
  systemStateVersion = "25.11";
  homeStateVersion = "25.11";

  # Storage / Hibernate
  resumeOffset = 1513128;

  # Hardware
  # Pure AMD host: gpuMode defaults to "amdgpu" via hardware-modules.nix.

  # Roles
  roles = [
    "vpn"
  ];

  # Credentials are managed by sops secrets:
  # - secrets/passwords/user-password.yaml
  # - secrets/passwords/root-password.yaml
}
