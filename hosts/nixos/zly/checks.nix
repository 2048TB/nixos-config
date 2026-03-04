args:
let
  hostVars = import ./vars.nix;
in
import ../_shared/checks.nix (args // {
  expectedVideoDrivers = [
    "nvidia"
    "amdgpu"
  ];
  expectedResumeOffset = hostVars.resumeOffset or null;
  expectedHostProfile = "zly";
  expectedAcceptFlakeConfig = hostVars.acceptFlakeConfig or false;
  expectedTrustedUsers = [ "root" ] ++ (hostVars.extraTrustedUsers or [ ]);
  expectedDockerMode = if builtins.elem "container" (hostVars.roles or [ ]) then (hostVars.dockerMode or "rootless") else "disabled";
  inherit (hostVars) cpuVendor;
})
