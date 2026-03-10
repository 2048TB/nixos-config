{
  pkgs,
  lib,
  myvars,
  osConfig ? null,
  ...
}:
let
  hostCfg = import ../base/resolve-host.nix { inherit myvars osConfig; };
  enableSteam = hostCfg.enableSteam or false;
in
{
  programs = {
    fzf.defaultOptions = [
      "--preview='bat --style=numbers --color=always --line-range=:200 {}'"
    ];

    mpv = {
      enable = true;
      defaultProfiles = [ "high-quality" ];
      scripts = [ pkgs.mpvScripts.mpris ];
    };

    # 由 Home Manager 管理 Lutris，统一 runner 与依赖集合
    lutris = lib.mkIf enableSteam {
      enable = true;
      defaultWinePackage = pkgs.proton-ge-bin;
      protonPackages = [ pkgs.proton-ge-bin ];
      winePackages = [
        pkgs.wineWowPackages.stable
      ];
      extraPackages = with pkgs; [
        winetricks
        gamescope
        gamemode
        mangohud
        umu-launcher
      ];
    };

    zsh.envExtra = ''
      export PKG_CONFIG_PATH="${pkgs.openssl.dev}/lib/pkgconfig''${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
    '';
  };
}
