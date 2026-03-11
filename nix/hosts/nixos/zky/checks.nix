args:
let
  hostVars = import ./vars.nix;
in
import ../_shared/checks.nix (args // {
  expectedLuksName = hostVars.luksName or "crypted-nixos";
  expectedResumeOffset = hostVars.resumeOffset or null;
})
