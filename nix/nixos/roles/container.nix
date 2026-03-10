{ lib, vars, ... }:
let
  dockerMode = vars.dockerMode or null;
in
lib.mkIf (dockerMode == "rootless") {
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };
}
