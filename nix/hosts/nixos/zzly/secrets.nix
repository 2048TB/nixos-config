{ hostSopsFile, ... }:
{
  sops.defaultSopsFile = hostSopsFile;

  # Host-only secrets declared in this module should use `hostSopsFile`.
  # Current host file: `secrets/nixos/zzly.yaml`
}
