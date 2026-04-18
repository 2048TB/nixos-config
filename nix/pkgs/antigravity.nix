{ lib
, callPackage
, vscode-generic
, fetchurl
, jq
, buildFHSEnv
, writeShellScript
, coreutils
, curl
, openssl
, webkitgtk_4_1
, libsoup_3
, commandLineArgs ? ""
, useVSCodeRipgrep ? false
,
}:

(callPackage vscode-generic {
  inherit commandLineArgs useVSCodeRipgrep;

  pname = "antigravity";
  version = "1.23.2";
  vscodeVersion = "1.107.0";

  executableName = "antigravity";
  longName = "Antigravity";
  shortName = "Antigravity";
  libraryName = "antigravity";
  iconName = "antigravity";

  src = fetchurl {
    url = "https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/1.23.2-4781536860569600/linux-x64/Antigravity.tar.gz";
    hash = "sha256-UjKkBI/0+hVoXZqYG6T7pXPil/PvybdvY455S693VyU=";
  };

  sourceRoot = "Antigravity";

  buildFHSEnv =
    args:
    buildFHSEnv (
      args
      // {
        extraBuildCommands = (args.extraBuildCommands or "") + ''
          mkdir -p "$out/opt/google/chrome"
        '';
        extraBwrapArgs = (args.extraBwrapArgs or [ ]) ++ [ "--tmpfs /opt/google/chrome" ];
        runScript = writeShellScript "antigravity-wrapper" ''
          for candidate in google-chrome-stable google-chrome chromium-browser chromium; do
            if target=$(command -v "$candidate"); then
              ${coreutils}/bin/ln -sf "$target" /opt/google/chrome/chrome
              break
            fi
          done
          exec ${args.runScript} "$@"
        '';
      }
    );

  tests = { };
  updateScript = writeShellScript "update-antigravity" ''
    echo "Manual update: bump version, vscodeVersion, URL, and hash in nix/pkgs/antigravity.nix"
  '';

  dontFixup = false;

  meta = {
    mainProgram = "antigravity";
    description = "Agentic development platform, evolving the IDE into the agent-first era";
    homepage = "https://antigravity.google";
    downloadPage = "https://antigravity.google/download";
    changelog = "https://antigravity.google/changelog";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
}).overrideAttrs
  (oldAttrs: {
    buildInputs = (oldAttrs.buildInputs or [ ]) ++ [
      curl
      openssl
      webkitgtk_4_1
      libsoup_3
    ];
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ jq ];
    postPatch = (oldAttrs.postPatch or "") + ''
      productJson="resources/app/product.json"
      data=$(jq 'del(.updateUrl)' "$productJson")
      echo "$data" > "$productJson"
    '';
  })
