{ config, pkgs, lib, myvars, mainUser, preservation, niri, ... }:
let
  # 系统常量
  defaultUid = 1000;
  defaultGid = 1000;
  gcRetentionDays = "7d";
  gcSchedule = "weekly";
  optimiseSchedule = [ "weekly" ];
  gnupgCacheTtlSeconds = 4 * 60 * 60; # 4 hours
in
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
      "/root" # root 用户配置（.bashrc, .vimrc, SSH keys 等）
      "/etc/NetworkManager/system-connections"
      "/etc/ssh"
      "/etc/nix"
      "/etc/secureboot"

      "/var/log"
      "/var/lib/nixos"
      "/var/lib/systemd"
      "/var/lib/NetworkManager"
      "/var/lib/bluetooth"
      "/var/lib/libvirt" # 虚拟机镜像和配置
      "/var/lib/docker" # Docker 镜像、容器和卷
      "/etc/mullvad-vpn"
      "/var/lib/flatpak"
    ];
    files = [
      {
        file = "/etc/machine-id";
        inInitrd = true;
      }
      {
        file = "/etc/user-password";
        inInitrd = true; # 用户密码文件需要在 initrd 阶段可用
        mode = "0600";
        user = "root";
        group = "root";
      }
      {
        file = "/etc/root-password";
        inInitrd = true; # root 密码文件用于紧急恢复
        mode = "0600";
        user = "root";
        group = "root";
      }
    ];

    # 用户目录已整体持久化到 /home（Btrfs @home 子卷）
    # 不再需要 preservation 模块管理用户目录
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

  # 确保 /persistent 在 initrd 阶段挂载（密码文件依赖）
  fileSystems."/persistent".neededForBoot = lib.mkDefault true;
  # greetd 依赖 /home/.wayland-session
  fileSystems."/home".neededForBoot = lib.mkDefault true;

  # outputs.nix 的 allowUnfree 仅影响 flake context，模块内仍需显式配置
  nixpkgs.config.allowUnfree = true;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];

    # 配置 Binary Cache 以加速包下载
    # 注意：niri.cachix.org 由 niri-flake 的 nixosModules.niri 自动添加（通过 niri-flake.cache.enable 选项，默认启用）
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
    dates = gcSchedule; # 每周执行一次
    options = "--delete-older-than ${gcRetentionDays}"; # 删除 7 天前的旧世代
  };

  # 优化配置
  nix.optimise = {
    automatic = true;
    dates = optimiseSchedule; # 每周优化存储
  };

  networking.hostName = myvars.hostname;
  networking.networkmanager.enable = true;
  networking.useDHCP = lib.mkDefault true;

  # 使 libvirt NAT 在 VPN 场景下更稳
  networking.firewall.checkReversePath = "loose";

  # 安全加固与桌面所需
  security.polkit = {
    enable = true;
    # 允许 wheel 组用户挂载 USB 等外部存储设备
    extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (
          subject.isInGroup("wheel")
          && action.id.match("org.freedesktop.udisks2.")
        ) {
          return polkit.Result.YES;
        }
      });
    '';
  };
  programs.dconf.enable = true;

  # GnuPG
  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-qt;
    enableSSHSupport = false;
    settings.default-cache-ttl = gnupgCacheTtlSeconds;
  };

  users.mutableUsers = true;

  # Root 用户配置（用于紧急恢复和单用户模式）
  users.users.root = {
    hashedPasswordFile = "/etc/root-password"; # preservation 从 /persistent/etc/root-password 绑定而来
  };

  users.groups.${mainUser} = {
    gid = defaultGid;
  };
  users.users.${mainUser} = {
    uid = defaultUid;
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "audio"
      "video"
      "input"
      "libvirtd"
      "kvm"
      "docker"
    ];
    shell = pkgs.zsh;
    hashedPasswordFile = "/etc/user-password"; # preservation 从 /persistent/etc/user-password 绑定而来
  };

  # 默认 Shell
  environment.shells = with pkgs; [
    bashInteractive
    zsh
  ];
  users.defaultUserShell = pkgs.zsh;
  programs.zsh.enable = true;

  services.xserver.enable = false;
  services.xserver.desktopManager.runXdgAutostartIfNone = true; # 启用 XDG autostart（fcitx5 等）

  # Niri compositor
  programs.niri = {
    enable = true;
    package = pkgs.niri; # 使用 nixpkgs 官方包（零编译）
  };

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
    jetbrains-mono # JetBrains Mono（2026 业界标准，优秀 CJK 兼容）
    maple-mono.NF-CN-unhinted # Nerd Font with Chinese glyphs（备用）

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
      qt6Packages.fcitx5-chinese-addons # 中文拼音输入法（Libpinyin 引擎）
      fcitx5-pinyin-zhwiki # 中文维基百科词库（提升识别准确率）
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
  services.udisks2.enable = true; # USB 设备自动识别和挂载

  # GNOME Keyring
  services.gnome.gnome-keyring.enable = true;
  programs.seahorse.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;

  # 首次启动时修复用户目录权限（由于安装脚本使用硬编码 UID）
  system.activationScripts.fixUserHomePerms = {
    text = ''
      if [ -d /home/${mainUser} ]; then
        chown -R ${mainUser}:${mainUser} /home/${mainUser} || true
      fi
    '';
    deps = [ "users" ];
  };

  # 时区
  time.timeZone = myvars.timezone;

  # 系统级最小软件
  environment.systemPackages = with pkgs; [
    # 编辑器（vim 由 home-manager 配置，此处仅保留 neovim 作为 root 用户编辑器）
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

  # Docker
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" ]; # 清理所有未使用的镜像（不仅悬空镜像）
    };
  };

  # Mullvad VPN 配置
  services.mullvad-vpn.enable = true;

  # 修复：防止 lockdown mode 在重启后阻断网络
  # 问题：tmpfs root + 持久化 /etc/mullvad-vpn 会保留 lockdown mode 设置
  # 解决：启动时强制禁用 lockdown mode，避免 VPN 连接失败时无网络
  systemd.services.mullvad-daemon.serviceConfig = {
    ExecStartPre = pkgs.writeShellScript "disable-mullvad-lockdown" ''
      settings_file="/etc/mullvad-vpn/settings.json"
      if [ -f "$settings_file" ]; then
        ${pkgs.jq}/bin/jq '.block_when_disconnected = false' "$settings_file" > "$settings_file.tmp"
        mv "$settings_file.tmp" "$settings_file"
        echo "Mullvad lockdown mode 已禁用（防止启动阻断网络）"
      fi
    '';
  };
  services.flatpak.enable = true;

  # 定期清理临时文件（模拟部分 tmpfs 优势）
  systemd.tmpfiles.rules = [
    # 确保持久化密码文件权限正确（存在时修正，不创建）
    "z /persistent/etc/user-password 0600 root root -"
    "z /persistent/etc/root-password 0600 root root -"
    # 7天清理缓存
    "e /home/${mainUser}/.cache - - - 7d"
    # 清理临时文件
    "e /tmp - - - 1d"
    "e /var/tmp - - - 7d"
    # 可选：清理特定应用缓存（取消注释以启用）
    # "e /home/${mainUser}/.cache/mozilla - - - 3d"
    # "e /home/${mainUser}/.cache/chromium - - - 3d"
    # "e /home/${mainUser}/.cache/thumbnails - - - 7d"
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
