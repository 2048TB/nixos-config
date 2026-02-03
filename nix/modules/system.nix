{ pkgs, lib, myvars, mainUser, ... }:
{
  # Boot loader
  boot.loader = {
    systemd-boot.enable = lib.mkDefault true;
    efi.canTouchEfiVariables = true;
  };

  # Secure Boot (lanzaboote) - 默认关闭
  boot.lanzaboote = {
    enable = lib.mkDefault false;
    pkiBundle = "/etc/secureboot";
  };

  # AMD CPU
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModprobeConfig = "options kvm_amd nested=1";

  # 支持的文件系统
  boot.supportedFilesystems = [
    "ext4"
    "btrfs"
    "xfs"
    "ntfs"
    "fat"
    "vfat"
    "exfat"
  ];

  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];

    # 配置 Binary Cache 以加速包下载
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://nixpkgs-wayland.cachix.org"
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
    ];

    # 信任 wheel 组用户使用自定义 substituters
    trusted-users = [ "root" "@wheel" ];

    # 自动优化存储（硬链接重复文件）
    auto-optimise-store = true;
  };

  # 自动垃圾回收配置
  nix.gc = {
    automatic = true;
    dates = "weekly";        # 每周执行一次
    options = "--delete-older-than 7d";  # 删除 7 天前的旧世代
  };

  # 优化配置
  nix.optimise = {
    automatic = true;
    dates = [ "weekly" ];    # 每周优化存储
  };

  networking.hostName = myvars.hostname;
  networking.networkmanager.enable = true;
  networking.useDHCP = lib.mkDefault true;

  # 使 libvirt NAT 在 VPN 场景下更稳
  networking.firewall.checkReversePath = "loose";

  # 安全加固与桌面所需
  security.polkit.enable = true;
  programs.dconf.enable = true;

  # GnuPG
  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-qt;
    enableSSHSupport = false;
    settings.default-cache-ttl = 4 * 60 * 60;
  };

  users.mutableUsers = true;
  users.groups.${mainUser} = {
    gid = 1000;
  };
  users.users.${mainUser} = {
    uid = 1000;
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "audio"
      "video"
      "input"
      "libvirtd"
      "kvm"
    ];
    shell = pkgs.zsh;
    hashedPasswordFile = "/persistent/etc/user-password";
  };

  # 默认 Shell
  environment.shells = with pkgs; [
    bashInteractive
    zsh
  ];
  users.defaultUserShell = pkgs.zsh;
  programs.zsh.enable = true;

  # 首次启动时修复 /persistent/home 权限（由于安装脚本使用硬编码 UID）
  system.activationScripts.fixPersistentHomePerms = {
    text = ''
      if [ -d /persistent/home/${mainUser} ]; then
        chown -R ${mainUser}:${mainUser} /persistent/home/${mainUser} || true
      fi
    '';
    deps = [ "users" ];
  };

  # 时区
  time.timeZone = "Asia/Shanghai";

  # 系统级最小软件
  environment.systemPackages = with pkgs; [
    vim
    neovim

    # 开发语言/工具链（系统级）
    rustc
    cargo
    rust-analyzer
    clippy
    rustfmt
    zig
    zls
    go
    gopls
    delve
    gotools
    nodejs
    nodePackages.typescript
    nodePackages.typescript-language-server
    python3
    pyright
    ruff
    black
    uv
  ];

  # 兼容通用 Linux 动态链接可执行文件（如第三方 CLI 安装器）
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc
      zlib
      openssl
    ];
  };
}
