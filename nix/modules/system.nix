{ config, pkgs, lib, myvars, mainUser, preservation, ... }:
{
  imports = [ preservation.nixosModules.default ];

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

  # preservation 需要 initrd systemd
  boot.initrd.systemd.enable = true;

  preservation.enable = true;
  preservation.preserveAt."/persistent" = {
    directories = [
      "/etc/NetworkManager/system-connections"
      "/etc/ssh"
      "/etc/nix"
      "/etc/secureboot"

      "/var/log"
      "/var/lib/nixos"
      "/var/lib/systemd"
      "/var/lib/NetworkManager"
      "/var/lib/bluetooth"
    ];
    files = [
      {
        file = "/etc/machine-id";
        inInitrd = true;
      }
    ];

    users.${mainUser} = {
      directories = [
        "Downloads"
        "Documents"
        "Pictures"
        "Videos"
        "Music"
        "nixos-config"
        ".config"
        ".local/share"
        ".local/state"
        ".cache"
      ];
    };
  };

  fileSystems."/" = lib.mkForce {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "relatime"
      "mode=755"
    ];
  };

  # swap 子卷：禁用 COW 和压缩以支持 swapfile
  fileSystems."/swap" = lib.mkForce {
    device =
      if config.fileSystems ? "/nix" && config.fileSystems."/nix" ? device
      then config.fileSystems."/nix".device
      else "/dev/mapper/crypted-nixos";
    fsType = "btrfs";
    options = [
      "subvol=@swap"
      "noatime"
      "nodatacow"
      "compress=no"
    ];
  };

  fileSystems."/swap/swapfile" = lib.mkForce {
    depends = [ "/swap" ];
    device = "/swap/swapfile";
    fsType = "none";
    options = [
      "bind"
      "rw"
    ];
  };

  swapDevices = [
    { device = "/swap/swapfile"; }
  ];

  fileSystems."/persistent".neededForBoot = lib.mkDefault true;

  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];

    # 配置 Binary Cache 以加速包下载
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://nixpkgs-wayland.cachix.org"
      "https://cache.garnix.io"
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
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

  services.xserver.enable = false;
  programs.niri.enable = true;

  services.greetd = {
    enable = true;
    settings.default_session = {
      user = mainUser;
      command = "/home/${mainUser}/.wayland-session";
    };
  };

  # Wayland 桌面常用的 portal（文件选择/截图/投屏）
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    config.common.default = [
      "gtk"
      "gnome"
    ];
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
    ];
  };

  fonts.packages = with pkgs; [
    # 编程字体
    maple-mono.NF-CN-unhinted # Nerd Font with Chinese glyphs

    # CJK 字体（已优化：移除 source-han 重复，仅保留 Noto）
    # 说明：source-han-sans 和 noto-fonts-cjk-sans 是同一套字体的不同品牌
    noto-fonts-cjk-sans # CJK 黑体（中日韩）
    noto-fonts-cjk-serif # CJK 宋体（中日韩）

    # 备用中文字体
    wqy_zenhei # 文泉驿正黑（轻量级，约 10MB）

    # 优化效果：移除 source-han-sans/serif 节省约 800MB
  ];

  # 输入法与中文支持
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      kdePackages.fcitx5-qt
      qt6Packages.fcitx5-configtool
      fcitx5-gtk
      (fcitx5-rime.override { rimeDataPkgs = [ rime-data ]; })
      qt6Packages.fcitx5-chinese-addons  # 中文拼音输入法
    ];
  };

  # 音频（含 32 位支持，便于 Steam/Proton）
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # 文件管理常用的缩略图/挂载支持
  services.gvfs.enable = true;
  services.tumbler.enable = true;

  # GNOME Keyring
  services.gnome.gnome-keyring.enable = true;
  programs.seahorse.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;

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
    lutris
  ];

  # 游戏支持
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
    protontricks.enable = true;
  };
  programs.gamemode.enable = true;

  # Proton-GE 配置：通过 Steam extraCompatPackages 安装
  # 注意：不能放在 environment.systemPackages（会导致 buildEnv 错误）
  programs.steam.extraCompatPackages = with pkgs; [
    proton-ge-bin
  ];

  # KVM / libvirt
  virtualisation.libvirtd.enable = true;
  virtualisation.libvirtd.qemu.swtpm.enable = true;
  programs.virt-manager.enable = true;

  services.mullvad-vpn.enable = true;
  services.flatpak.enable = true;

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
