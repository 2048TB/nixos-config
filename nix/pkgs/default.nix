pkgs:
let
  mylib = import ../lib { inherit (pkgs) lib; };
  resolved = mylib.resolvePackagesByName pkgs mylib.sharedPackageNames;
  sharedCli = pkgs.symlinkJoin {
    name = "nixos-config-shared-cli";
    paths = resolved.packages;
  };
in
{
  default = sharedCli;
  shared-cli = sharedCli;
}
