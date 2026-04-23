{ pkgs
, lib
, config
, ...
}:
let
  hostCfg = config.my.host;
  inherit (config.my.capabilities) hasDesktopSession;
  gnupgCacheTtlSeconds = 4 * 60 * 60; # 4 小时
in
lib.mkIf hasDesktopSession {
  programs = {
    appimage = {
      enable = true;
      binfmt = true;
    };

    dconf.enable = true;

    gnupg.agent = {
      enable = true;
      pinentryPackage = pkgs.pinentry-qt;
      enableSSHSupport = false;
      settings.default-cache-ttl = toString gnupgCacheTtlSeconds;
    };

    river-classic = lib.mkIf (hostCfg.desktopProfile == "river") {
      enable = true;
      package = null;
      extraPackages = [ ];
    };

    seahorse.enable = true;

    nix-ld = {
      enable = true;
      # appimageTools 提供的默认 FHS 环境共享库集：glibc, mesa, vulkan-loader, libva 等。
      # 覆盖预编译二进制的常见运行时依赖。
      libraries =
        (pkgs.appimageTools.defaultFhsEnvArgs.multiPkgs pkgs)
        ++ (with pkgs; [
          openssl
        ]);
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
    maple-mono.NF-CN-unhinted

    noto-fonts-color-emoji
    noto-fonts # 数学符号、箭头、特殊字符等后备字体
    dejavu_fonts # 最终后备字体（覆盖 Latin/Greek/Cyrillic + 等宽）

    sarasa-gothic # CJK sans（基于 Source Han Sans + Inter）
    noto-fonts-cjk-sans # CJK sans fallback（Chrome/fontconfig 默认匹配）
    noto-fonts-cjk-serif # CJK serif（独立字型类别）
  ];

  fonts.fontconfig.defaultFonts = {
    sansSerif = [ "Sarasa Gothic SC" "Noto Sans CJK SC" "Noto Sans" ];
    serif = [ "Noto Serif CJK SC" "Noto Serif" ];
    monospace = [ "Cascadia Code" "Sarasa Term SC" ];
  };

  i18n = {
    defaultLocale = hostCfg.locale;
    extraLocales = [ "en_US.UTF-8/UTF-8" ];
    inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5.waylandFrontend = true;
      fcitx5.addons = with pkgs; [
        kdePackages.fcitx5-qt
        qt6Packages.fcitx5-configtool
        fcitx5-gtk
        (fcitx5-rime.override {
          rimeDataPkgs = [ rime-ice ];
        })
      ];
    };
  };

  environment.systemPackages =
    with pkgs;
    [
      xwayland-satellite
    ]
    ++ lib.optionals (hostCfg.desktopProfile == "river") [
      kwm-river
      river-kwm-session
    ];

  services.displayManager.sessionPackages = lib.optionals (hostCfg.desktopProfile == "river") [
    pkgs.river-kwm-session
  ];
}
