pkgs:
let
  mylib = import ../lib { inherit (pkgs) lib; };
  resolved = mylib.resolvePackagesByName pkgs mylib.sharedPackageNames;
in
{
  default = pkgs.symlinkJoin {
    name = "nixos-config-shared-cli";
    paths = resolved.packages;
  };

  shared-cli = pkgs.symlinkJoin {
    name = "nixos-config-shared-cli";
    paths = resolved.packages;
  };
}
