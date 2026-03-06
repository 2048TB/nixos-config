{ lib, myvars, ... }:
let
  allowedGpuModes = [
    "auto"
    "none"
    "amd"
    "amdgpu"
    "nvidia"
    "nvidia-prime"
    "modesetting"
    "amd-nvidia-hybrid"
  ];
  allowedCpuVendors = [
    "auto"
    "amd"
    "intel"
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
  extraTrustedUsers = myvars.extraTrustedUsers or [ ];
  trustedUserAllowlist = [ myvars.username ];
  appToggleNames = [
    "enableWpsOffice"
    "enableZathura"
    "enableSplayer"
    "enableTelegramDesktop"
    "enableLocalSend"
  ];
  appToggleAssertions = map
    (
      optName:
      {
        assertion =
          !(builtins.hasAttr optName myvars)
          || builtins.isBool (builtins.getAttr optName myvars);
        message = "myvars.${optName} must be a boolean (true/false).";
      }
    )
    appToggleNames;

  userPasswordSecretFile = ../../../secrets/passwords/user-password.age;
  rootPasswordSecretFile = ../../../secrets/passwords/root-password.age;
in
{
  assertions = [
    {
      assertion = builtins.elem (myvars.gpuMode or "auto") allowedGpuModes;
      message = "myvars.gpuMode must be one of: auto, none, amd, amdgpu, nvidia, nvidia-prime, modesetting, amd-nvidia-hybrid.";
    }
    {
      assertion = builtins.elem (myvars.cpuVendor or "auto") allowedCpuVendors;
      message = "myvars.cpuVendor must be one of: auto, amd, intel.";
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
    {
      assertion = builtins.isList extraTrustedUsers;
      message = "myvars.extraTrustedUsers must be a list (e.g. [ \"z\" ]).";
    }
    {
      assertion = builtins.all builtins.isString extraTrustedUsers;
      message = "myvars.extraTrustedUsers must contain only strings.";
    }
    {
      assertion = lib.subtractLists trustedUserAllowlist extraTrustedUsers == [ ];
      message = "myvars.extraTrustedUsers contains disallowed users. allowed: only myvars.username.";
    }
  ] ++ appToggleAssertions;
}
