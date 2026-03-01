{ lib, myvars, ... }:
let
  allowedGpuModes = [
    "auto"
    "none"
    "amd"
    "amdgpu"
    "nvidia"
    "modesetting"
    "amd-nvidia-hybrid"
  ];
  knownHostRoles = [
    "desktop"
    "gaming"
    "vpn"
    "virt"
    "container"
  ];
  hostRoles = myvars.roles or [ "desktop" ];
  enableHibernate = myvars.enableHibernate or true;

  userPasswordSecretFile = ../../../secrets/passwords/user-password.age;
  rootPasswordSecretFile = ../../../secrets/passwords/root-password.age;
in
{
  assertions = [
    {
      assertion = builtins.elem (myvars.gpuMode or "auto") allowedGpuModes;
      message = "myvars.gpuMode must be one of: auto, none, amd, amdgpu, nvidia, modesetting, amd-nvidia-hybrid.";
    }
    {
      assertion = builtins.pathExists userPasswordSecretFile;
      message = "Missing secrets/passwords/user-password.age. Use agenix to create/update it.";
    }
    {
      assertion = builtins.pathExists rootPasswordSecretFile;
      message = "Missing secrets/passwords/root-password.age. Use agenix to create/update it.";
    }
    {
      assertion =
        (!enableHibernate)
        || (
          myvars ? resumeOffset
          && myvars.resumeOffset != null
          && builtins.isInt myvars.resumeOffset
          && myvars.resumeOffset > 0
        );
      message = "When myvars.enableHibernate=true, set a positive integer myvars.resumeOffset (btrfs inspect-internal map-swapfile -r /swap/swapfile).";
    }
    {
      assertion = builtins.isList hostRoles;
      message = "myvars.roles must be a list (e.g. [ \"desktop\" \"container\" ]).";
    }
    {
      assertion = lib.subtractLists knownHostRoles hostRoles == [ ];
      message = "myvars.roles contains unknown values. allowed: desktop, gaming, vpn, virt, container.";
    }
  ];
}
