{ config, pkgs, lib, mylib, myvars, osConfig ? null, userProfileBin, ... }:
let
  hostCfg = import ../base/resolve-host.nix { inherit myvars osConfig; };
  configRepoPath = hostCfg.configRepoPath or mylib.hostMetaSchema.defaultConfigRepoPath;
  hasDesktopSession = hostCfg.desktopSession or false;
  enableAntigravity = myvars.enableAntigravity or false;
  homeDir = config.home.homeDirectory;
  miseShimDir = "${homeDir}/.local/share/mise/shims";
  chromiumArgWarningFilters = [
    "Warning: 'ozone-platform-hint' is not in the list of known options, but still passed to Electron/Chromium."
    "Warning: 'enable-features' is not in the list of known options, but still passed to Electron/Chromium."
    "Warning: 'enable-wayland-ime' is not in the list of known options, but still passed to Electron/Chromium."
    "Warning: 'wayland-text-input-version' is not in the list of known options, but still passed to Electron/Chromium."
  ];
  mkSedDeleteExpr = pattern:
    let
      escapedPattern = lib.replaceStrings [ "/" ] [ "\\/" ] pattern;
    in
    "/${escapedPattern}/d";
  chromiumArgWarningDeleteArgs =
    lib.concatMapStringsSep " \\\n"
      (pattern: "      -e ${lib.escapeShellArg (mkSedDeleteExpr pattern)}")
      chromiumArgWarningFilters;
  mkGuiCliWrapper = binaryName: targetExe: pkgs.writeShellApplication {
    name = binaryName;
    text = ''
          export CHECKPOINTING=false
          export PATH="${miseShimDir}:$PATH"

          # Use an explicit package executable instead of PATH lookup; PATH is
          # intentionally changed above for mise shims and can otherwise recurse.
          target=${lib.escapeShellArg targetExe}
          if [ ! -x "$target" ]; then
            echo "${binaryName}: target executable not found or not executable: $target" >&2
            exit 127
          fi

          self_real="$(${pkgs.coreutils}/bin/readlink -f "$0" 2>/dev/null || printf '%s\n' "$0")"
          target_real="$(${pkgs.coreutils}/bin/readlink -f "$target" 2>/dev/null || printf '%s\n' "$target")"
          if [ "$self_real" = "$target_real" ]; then
            echo "${binaryName}: refusing to execute wrapper recursively: $target" >&2
            exit 126
          fi

          exec 3>&2
          "$target" "$@" \
            2> >(
              ${pkgs.gnused}/bin/sed -u \
      ${chromiumArgWarningDeleteArgs} \
                >&3
            )
    '';
  };
  codeTarget = lib.getExe pkgs.vscode;
  antigravityTarget =
    if hasDesktopSession && enableAntigravity && pkgs ? antigravity then
      lib.getExe pkgs.antigravity
    else
      "${userProfileBin}/antigravity";
  resolvedCodeTarget =
    if hasDesktopSession then
      codeTarget
    else
      "${userProfileBin}/code";
in
{
  home.activation.warnNixosRepoPath = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -d ${lib.escapeShellArg configRepoPath} ]; then
      echo "warning: ~/nixos points to missing configRepoPath: ${configRepoPath}" >&2
    fi
  '';

  home.file = {
    # 便捷入口：保持 /etc/nixos 作为系统入口，同时在主目录提供快速访问路径
    "nixos".source = config.lib.file.mkOutOfStoreSymlink configRepoPath;
    # Noctalia 默认扫描 ~/Pictures/Wallpapers，保持与仓库壁纸目录同步。
    "Pictures/Wallpapers" = {
      source = ../../../wallpapers;
      recursive = true;
    };

    "tools/x86_64-w64-mingw32-gcc" = {
      executable = true;
      text = ''
        #!${pkgs.runtimeShell}
        exec ${pkgs.pkgsCross.mingwW64.stdenv.cc}/bin/x86_64-w64-mingw32-gcc \
          -L${pkgs.pkgsCross.mingwW64.windows.mcfgthreads}/lib \
          -L${pkgs.pkgsCross.mingwW64.windows.pthreads}/lib \
          "$@"
      '';
    };

    "tools/x86_64-w64-mingw32-g++" = {
      executable = true;
      text = ''
        #!${pkgs.runtimeShell}
        exec ${pkgs.pkgsCross.mingwW64.stdenv.cc}/bin/x86_64-w64-mingw32-g++ \
          -L${pkgs.pkgsCross.mingwW64.windows.mcfgthreads}/lib \
          -L${pkgs.pkgsCross.mingwW64.windows.pthreads}/lib \
          "$@"
      '';
    };

    ".cargo/config.toml".text = ''
      [target.x86_64-pc-windows-gnu]
      linker = "${homeDir}/tools/x86_64-w64-mingw32-gcc"
      rustflags = [
        "-Lnative=${pkgs.pkgsCross.mingwW64.windows.mcfgthreads}/lib",
        "-Lnative=${pkgs.pkgsCross.mingwW64.windows.pthreads}/lib"
      ]
    '';
    ".yarnrc".text = ''
      prefix "${homeDir}/.local"
    '';

    ".local/bin/code" = {
      executable = true;
      source = lib.getExe (mkGuiCliWrapper "code" resolvedCodeTarget);
    };

    ".local/bin/antigravity" = {
      executable = true;
      source = lib.getExe (mkGuiCliWrapper "antigravity" antigravityTarget);
    };
  };
}
