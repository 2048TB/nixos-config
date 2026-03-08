{ lib }:
{
  mkLogFilteredLauncher =
    pkgs: name: executable: filters:
    let
      mkSedDeleteExpr = pattern:
        let
          escapedPattern = lib.replaceStrings [ "/" ] [ "\\/" ] pattern;
        in
        "/${escapedPattern}/d";
      sedDeleteArgs =
        lib.concatMapStringsSep " \\\n"
          (pattern: "          -e ${lib.escapeShellArg (mkSedDeleteExpr pattern)}")
          filters;
    in
    pkgs.writeShellScriptBin name ''
            set -euo pipefail
            sedBin="${pkgs.gnused}/bin/sed"

            set +e
            ${executable} "$@" 2>&1 \
              | "$sedBin" -u -E \
      ${sedDeleteArgs}
              >&2
            status="''${PIPESTATUS[0]}"
            set -e
            exit "$status"
    '';
}
