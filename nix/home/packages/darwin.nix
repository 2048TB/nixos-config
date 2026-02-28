{ lib, pkgs }:
let
  sharedNames = import ./shared.nix;

  # Keep package names as strings so missing attrs on Darwin won't break eval.
  darwinExtraNames = [
    # Programming languages and toolchains
    "go"
    "rustup"
    "nodejs_22"
    "python3"
    "bun"
    "pnpm"
    "pipx"
    "zig"

    # CLI tools
    "gitui"
    "delta"
    "tealdeer"
    "duf"
    "dust"
    "procs"

  ];
  desiredPackageNames = sharedNames ++ darwinExtraNames;

  resolvePackage = name:
    let
      pkgPath = lib.splitString "." name;
      pkg = lib.attrByPath pkgPath null pkgs;
      exists = pkg != null;
      availability =
        if exists
        then builtins.tryEval (lib.meta.availableOn pkgs.stdenv.hostPlatform pkg)
        else {
          success = true;
          value = false;
        };
      available = exists && availability.success && availability.value;
    in
    {
      inherit name pkg exists available;
    };

  resolved = map resolvePackage desiredPackageNames;
in
{
  packages = map (item: item.pkg) (builtins.filter (item: item.available) resolved);
  skippedNames = map (item: item.name) (builtins.filter (item: !item.available) resolved);
}
