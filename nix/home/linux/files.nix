{ config, pkgs, configRepoPath, ... }:
let
  homeDir = config.home.homeDirectory;
in
{
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
  };
}
