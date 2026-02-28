{ mylib, ... }@args:
let
  name = "zly-mac";
  hostDir = "hosts/darwin/${name}";
  hostCtx = mylib.mkDarwinHost (args // {
    inherit name;
    hostPath = mylib.relativeToRoot "${hostDir}/default.nix";
    hostHomeModulePath = mylib.relativeToRoot "${hostDir}/home.nix";
  });
  hostChecks = import (mylib.relativeToRoot "${hostDir}/checks.nix") hostCtx;
in
{
  darwinConfigurations.${hostCtx.name} = hostCtx.darwinSystem;
  checks.${hostCtx.system} = hostChecks;
}
