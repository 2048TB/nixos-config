args:
let
  hostVars = import ./vars.nix;
  cpuVendor = args.mylib.cpuVendorFromHardwareModules (import ./hardware-modules.nix);
in
import ../_shared/checks.nix (args // {
  expectedLuksName = hostVars.luksName or "crypted-nixos";
  expectedVideoDrivers = [ "amdgpu" ];
  expectedResumeOffset = hostVars.resumeOffset or null;
  expectedHostProfile = "zzly";
  expectedTrustedUsers = [ "root" ];
  expectedDockerMode = if builtins.elem "container" (hostVars.roles or [ ]) then (hostVars.dockerMode or "rootless") else "disabled";
  inherit cpuVendor;
})
