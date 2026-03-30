{ pkgs
, lib
, config
, ...
}:
let
  inherit (config.my.capabilities) hasDesktopSession;
  gnupgCacheTtlSeconds = 4 * 60 * 60; # 4 小时
in
lib.mkIf hasDesktopSession {
  programs = {
    dconf.enable = true;

    gnupg.agent = {
      enable = true;
      pinentryPackage = pkgs.pinentry-qt;
      enableSSHSupport = false;
      settings.default-cache-ttl = toString gnupgCacheTtlSeconds;
    };

    zsh.enable = true;

    "river-classic" = {
      enable = true;
      xwayland.enable = true;
      extraPackages = with pkgs; [
        foot
      ];
    };

    seahorse.enable = true;

    nix-ld = {
      enable = true;
      # steam-run FHS 环境的共享库集（multiPkgs）：glibc, mesa, vulkan-loader, libva 等。
      # 覆盖非 Steam 游戏（Heroic/itch.io 等）和预编译二进制的常见运行时依赖。
      libraries =
        (pkgs.steam-run.passthru.args.multiPkgs pkgs)
        ++ (with pkgs; [
          openssl
        ]);
    };
  };

  environment.shells = with pkgs; [
    bashInteractive
    zsh
  ];

  # portal 由 programs.river-classic 模块自动配置（wlr + gtk backends）
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
        (fcitx5-rime.override {
          rimeDataPkgs = [ rime-ice ];
        })
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    xwayland-satellite
    wsdd # gvfsd-wsdd 通过 execvp 调用 wsdd，需在系统 PATH 中
  ];
}
