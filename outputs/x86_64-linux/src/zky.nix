{ mylib, ... }@args:
let
  name = "zky";
  hostDir = "hosts/nixos/${name}";
  hostCtx = mylib.mkNixosHost (args // {
    inherit name;
    hostPath = mylib.relativeToRoot "${hostDir}/default.nix";
    hostMyvars = {
      gpuMode = "amd";
      resumeOffset = 533760;
    };
  });
  hostChecks = import (mylib.relativeToRoot "${hostDir}/checks.nix") (hostCtx // { inherit (args) lib; });
in
{
  nixosConfigurations.${hostCtx.name} = hostCtx.nixosSystem;
  checks.${hostCtx.system} = hostChecks;
}
