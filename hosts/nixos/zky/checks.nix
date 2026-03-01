args:
let
  hostVars = import ./vars.nix;
in
import ../_shared/checks.nix (args // {
  expectedVideoDrivers = [ "amdgpu" ];
  expectedResumeOffset = hostVars.resumeOffset or null;
  expectedHostProfile = "zky";
})
