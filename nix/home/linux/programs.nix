{ config, pkgs, lib, mylib, myvars, osConfig ? null, ... }:
let
  hostCfg = import ../base/resolve-host.nix { inherit myvars osConfig; };
  roleFlags = mylib.roleFlags hostCfg;
  inherit (roleFlags) enableSteam;
  hasDesktopSession = hostCfg.desktopSession or false;
  aria2Cfg = hostCfg.aria2 or { };
  aria2EnableRpc = aria2Cfg.enableRpc or true;
  aria2SessionDir = "${config.home.homeDirectory}/.local/share/aria2";
  aria2SessionFile = "${aria2SessionDir}/session";
  aria2DownloadDir = "${config.home.homeDirectory}/Downloads";
  aria2BaseSettings = {
    dir = aria2DownloadDir;
    "continue" = true;
    "enable-rpc" = aria2EnableRpc;
    "input-file" = aria2SessionFile;
    "save-session" = aria2SessionFile;
    "save-session-interval" = 60;
  };
  aria2RpcSettings = lib.optionalAttrs aria2EnableRpc {
    "rpc-listen-port" = 6800;
    # 仅监听 localhost；扩展通过本机 6800/jsonrpc 访问 aria2 RPC。
    "rpc-listen-all" = false;
    # 浏览器扩展运行在 chrome-extension:// origin，下发 ACAO 头可避免被同源策略拦截。
    "rpc-allow-origin-all" = true;
  };
in
{
  programs = {
    aria2 = lib.mkIf hasDesktopSession {
      enable = true;
      settings = aria2BaseSettings // aria2RpcSettings;
    };

    fzf.defaultOptions = [
      "--preview='bat --style=numbers --color=always --line-range=:200 {}'"
    ];

    mpv = lib.mkIf hasDesktopSession {
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
