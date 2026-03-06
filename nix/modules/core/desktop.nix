{ pkgs
, lib
, ...
}:
let
  gnupgCacheTtlSeconds = 4 * 60 * 60; # 4 小时
  portalConfig = import ./portal-config.nix;
  # 仅将 MinGW 交叉编译器的可执行文件加入 system path，避免与本机 gcc 的文档路径冲突告警。
  mingwToolchainBinOnly = pkgs.buildEnv {
    name = "mingw-w64-toolchain-bin-only";
    paths = [ pkgs.pkgsCross.mingwW64.stdenv.cc ];
    pathsToLink = [ "/bin" ];
  };
in
{
  programs = {
    dconf.enable = true;

    gnupg.agent = {
      enable = true;
      pinentryPackage = pkgs.pinentry-qt;
      enableSSHSupport = false;
      settings.default-cache-ttl = toString gnupgCacheTtlSeconds;
    };

    zsh.enable = true;
    niri = {
      enable = true;
      useNautilus = false;
    };

    seahorse.enable = true;

    nix-ld = {
      enable = true;
      libraries = with pkgs; [
        stdenv.cc.cc
        zlib
        openssl
      ];
    };
  };

  environment.shells = with pkgs; [
    bashInteractive
    zsh
    nushell
  ];

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    config = portalConfig;
    extraPortals = lib.mkForce (with pkgs; [
      xdg-desktop-portal-gnome
    ]);
  };

  fonts.packages = with pkgs; [
    cascadia-code
    jetbrains-mono
    fira-code
    sarasa-gothic
    maple-mono.NF-CN-unhinted

    noto-fonts-color-emoji

    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    wqy_zenhei
  ];

  i18n = {
    defaultLocale = "zh_CN.UTF-8";
    extraLocales = [ "en_US.UTF-8/UTF-8" ];
    inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5.waylandFrontend = true;
      fcitx5.addons = with pkgs; [
        kdePackages.fcitx5-qt
        qt6Packages.fcitx5-configtool
        fcitx5-gtk
        qt6Packages.fcitx5-chinese-addons
        fcitx5-pinyin-zhwiki
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    neovim

    (rust-bin.stable.latest.default.override {
      targets = [ "x86_64-pc-windows-gnu" ];
    })
    rust-bin.stable.latest.rust-analyzer
    mingwToolchainBinOnly
    zig
    zls
    go
    gcc
    gopls
    delve
    gotools
    nodejs
    nodePackages.typescript
    nodePackages.typescript-language-server
    python3
    python3Packages.pip
    pyright
    ruff
    black
    uv
    xwayland-satellite
  ];
}
