{ config, pkgs, lib, configRepoPath, userProfileBin, ... }:
let
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
  mkGuiCliWrapper = binaryName: pkgs.writeShellApplication {
    name = binaryName;
    text = ''
          export CHECKPOINTING=false
          # Electron 类应用在 River/Wayland 下仍存在 IME 边缘情况；
          # 将 GTK IM module 限定在 wrapper 内，避免全局污染 GTK 应用。
          export GTK_IM_MODULE=fcitx
          export QT_IM_MODULES="wayland;fcitx;ibus"
          export PATH="${miseShimDir}:$PATH"

          exec 3>&2
          "${userProfileBin}/${binaryName}" "$@" \
            2> >(
              ${pkgs.gnused}/bin/sed -u \
      ${chromiumArgWarningDeleteArgs} \
                >&3
            )
    '';
  };
in
{
  home.file = {
    # 便捷入口：保持 /etc/nixos 作为系统入口，同时在主目录提供快速访问路径
    "nixos".source = config.lib.file.mkOutOfStoreSymlink configRepoPath;
    # 保持与仓库壁纸目录同步，供桌面手动选用。
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
      source = lib.getExe (mkGuiCliWrapper "code");
    };

    ".local/bin/antigravity" = {
      executable = true;
      source = lib.getExe (mkGuiCliWrapper "antigravity");
    };
  };
}
