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

    ".cargo/config.toml".text = ''
      [target.x86_64-pc-windows-gnu]
      linker = "x86_64-w64-mingw32-gcc"
      rustflags = [
        "-Lnative=${pkgs.pkgsCross.mingwW64.windows.pthreads}/lib"
      ]
    '';
    ".yarnrc".text = ''
      prefix "${homeDir}/.local"
    '';
  };
}
