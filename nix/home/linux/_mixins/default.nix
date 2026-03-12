_:
let
  linuxDir = builtins.dirOf ./.;
in
map
  (name: linuxDir + "/${name}")
  [
    "desktop.nix"
    "files.nix"
    "packages.nix"
    "programs.nix"
    "session.nix"
    "xdg.nix"
  ]
