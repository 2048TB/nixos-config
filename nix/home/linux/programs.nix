{ pkgs, lib, mylib, myvars, ... }:
let
  roleFlags = mylib.roleFlags myvars;
  inherit (roleFlags) enableSteam;
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

    nushell.extraEnv = ''
      let existing_pkg_config_path = ($env.PKG_CONFIG_PATH? | default "")
      $env.PKG_CONFIG_PATH = if ($existing_pkg_config_path | is-empty) {
        "${pkgs.openssl.dev}/lib/pkgconfig"
      } else {
        $"${pkgs.openssl.dev}/lib/pkgconfig:($existing_pkg_config_path)"
      }
    '';
  };
}
