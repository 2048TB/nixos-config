{ pkgs
, lib
, config
, ...
}:
let
  isDesktop = config.my.profiles.desktop;
  gnupgCacheTtlSeconds = 4 * 60 * 60; # 4 小时
in
lib.mkIf isDesktop {
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
  ];

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
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
    xwayland-satellite
  ];
}
