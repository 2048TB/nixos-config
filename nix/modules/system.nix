{ config, pkgs, lib, myvars, mainUser, preservation, ... }:
let
  # 系统常量
  defaultUid = 1000;
  defaultGid = 1000;
  gcRetentionDays = "7d";
  gnupgCacheTtlSeconds = 4 * 60 * 60; # 4 小时
  homeDir = "/home/${mainUser}";

  # 密码文件必须在 initrd 可用，且权限固定
  passwordFileAttrs = {
    inInitrd = true;
    mode = "0600";
    user = "root";
    group = "root";
  };

  hasAmd = config.hardware.cpu.amd.updateMicrocode or false;
  hasIntel = config.hardware.cpu.intel.updateMicrocode or false;
  kvmModules =
    if hasAmd || hasIntel
    then
      (lib.optionals hasAmd [ "kvm-amd" ])
      ++ (lib.optionals hasIntel [ "kvm-intel" ])
    else [ "kvm-amd" "kvm-intel" ];
  kvmExtraModprobeConfig = lib.concatStringsSep "\n" (lib.flatten [
    (lib.optional hasAmd "options kvm_amd nested=1")
    (lib.optional hasIntel "options kvm_intel nested=1")
  ]);
in
{
  imports = [ preservation.nixosModules.default ];

  boot = {
    # 引导加载器
    loader = {
      systemd-boot.enable = lib.mkDefault true;
      efi.canTouchEfiVariables = true;
    };

    # 安全启动（lanzaboote）- 默认关闭
    lanzaboote = {
      enable = lib.mkDefault false;
      pkiBundle = "/etc/secureboot";
    };

    # KVM 内核模块（AMD/Intel）
    kernelModules = kvmModules;
    extraModprobeConfig = kvmExtraModprobeConfig;

    # 支持的文件系统
    supportedFilesystems = [
      "ext4"
      "btrfs"
      "xfs"
      "ntfs"
      "fat"
      "vfat"
      "exfat"
    ];

    # preservation 需要 initrd 的 systemd
    initrd.systemd.enable = true;
  };

  preservation.enable = true;
  preservation.preserveAt."/persistent" = {
    directories = [
      "/root" # root 账户配置（.bashrc、.vimrc、SSH 密钥等）
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
      (passwordFileAttrs // { file = "/etc/user-password"; }) # 用户密码文件
      (passwordFileAttrs // { file = "/etc/root-password"; }) # root 账户密码文件
    ];

    # 用户目录已整体持久化到 /home（Btrfs @home 子卷）
    # 不再需要 preservation 模块管理用户目录
  };

  fileSystems = {
    "/" = lib.mkForce {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [
        "relatime"
        "mode=755"
      ];
    };

    # swap 子卷：禁用写时复制（COW）和压缩以支持交换文件
    "/swap" = lib.mkForce {
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

    "/swap/swapfile" = lib.mkForce {
      depends = [ "/swap" ];
      device = "/swap/swapfile";
      fsType = "none";
      options = [
        "bind"
        "rw"
      ];
    };

    # 确保 /persistent 在 initrd 阶段挂载（密码文件依赖）
    "/persistent" = {
      neededForBoot = lib.mkDefault true;
    };

    # greetd 依赖 /home/.wayland-session
    "/home" = {
      neededForBoot = lib.mkDefault true;
    };
  };

  swapDevices = [
    { device = "/swap/swapfile"; }
  ];


  # outputs.nix 的 allowUnfree 仅影响 flake 上下文，模块内仍需显式配置
  nixpkgs.config.allowUnfree = true;

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];

      # 配置二进制缓存以加速包下载
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

      # 信任 wheel 组用户使用自定义替代源（substituters）
      trusted-users = [ "root" "@wheel" ];

      # 自动优化存储（硬链接重复文件）
      auto-optimise-store = true;
    };

    # 自动垃圾回收配置
    gc = {
      automatic = true;
      dates = "weekly"; # 每周执行一次
      options = "--delete-older-than ${gcRetentionDays}"; # 删除 7 天前的旧世代
    };

    # 优化配置
    optimise = {
      automatic = true;
      dates = [ "weekly" ]; # 每周优化存储
    };
  };

  networking = {
    hostName = myvars.hostname;
    networkmanager.enable = true;
    useDHCP = lib.mkDefault true;

    # 使 libvirt NAT 在 VPN 场景下更稳
    firewall.checkReversePath = "loose";
  };

  # 安全加固与桌面所需
  security = {
    polkit = {
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
    pam.services.greetd.enableGnomeKeyring = true;
  };

  programs = {
    dconf.enable = true;

    # GnuPG 代理
    gnupg.agent = {
      enable = true;
      pinentryPackage = pkgs.pinentry-qt;
      enableSSHSupport = false;
      settings.default-cache-ttl = toString gnupgCacheTtlSeconds;
    };

    zsh.enable = true;

    # Niri 合成器
    niri = {
      enable = true;
      package = pkgs.niri; # 使用 nixpkgs 官方包（零编译）
    };

    seahorse.enable = true;

    # 游戏支持
    steam = {
      enable = true;
      gamescopeSession.enable = true;
      protontricks.enable = true;

      # Proton-GE 配置：通过 Steam 的 extraCompatPackages 安装
      # 注意：不能放在 environment.systemPackages（会导致 buildEnv 错误）
      extraCompatPackages = with pkgs; [
        proton-ge-bin
      ];
    };

    gamemode.enable = true;

    # KVM / libvirt 虚拟化管理
    virt-manager.enable = true;

    # 兼容通用 Linux 动态链接可执行文件（如第三方 CLI 安装器）
    nix-ld = {
      enable = true;
      libraries = with pkgs; [
        stdenv.cc.cc
        zlib
        openssl
      ];
    };
  };

  # 配合 tmpfs 根分区，用户数据库由配置统一管理，避免 passwd 修改丢失
  users = {
    mutableUsers = false;

    # root 账户配置（用于紧急恢复和单用户模式）
    users.root = {
      hashedPasswordFile = "/etc/root-password"; # preservation 从 /persistent/etc/root-password 绑定而来
    };

    groups.${mainUser} = {
      gid = defaultGid;
    };

    users.${mainUser} = {
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

    defaultUserShell = pkgs.zsh;
  };

  # 默认 Shell
  environment.shells = with pkgs; [
    bashInteractive
    zsh
  ];

  services = {
    xserver = {
      enable = false;
      desktopManager.runXdgAutostartIfNone = true; # 启用 XDG 自启动（fcitx5 等）
    };

    greetd = {
      enable = true;
      settings.default_session = {
        user = mainUser;
        command = "${homeDir}/.wayland-session";
      };
    };

    # 音频（含 32 位支持，便于 Steam/Proton）
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    # 文件管理常用的缩略图/挂载支持
    gvfs.enable = true;
    tumbler.enable = true;
    udisks2.enable = true; # USB 设备自动识别和挂载

    # GNOME 密钥环
    gnome.gnome-keyring.enable = true;

    # Mullvad VPN
    mullvad-vpn.enable = true;

    flatpak.enable = true;
  };

  # Wayland 桌面常用门户（文件选择/截图/投屏）
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
    maple-mono.NF-CN-unhinted # Nerd Font（含中文字形，备用）

    # 中日韩字体（已优化：移除 source-han 重复，仅保留 Noto）
    # 说明：source-han-sans 和 noto-fonts-cjk-sans 是同一套字体的不同品牌
    noto-fonts-cjk-sans # 中日韩黑体
    noto-fonts-cjk-serif # 中日韩宋体

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

  # 首次启动时修复用户目录权限（由于安装脚本使用硬编码 UID）
  system.activationScripts.fixUserHomePerms = {
    text = ''
      if [ -d ${homeDir} ] && id -u ${mainUser} >/dev/null 2>&1; then
        current_uid=$(stat -c %u ${homeDir} 2>/dev/null || echo "")
        target_uid=$(id -u ${mainUser})
        if [ -n "$current_uid" ] && [ "$current_uid" != "$target_uid" ]; then
          find ${homeDir} -xdev \( -not -user ${mainUser} -o -not -group ${mainUser} \) \
            -exec chown ${mainUser}:${mainUser} {} + || true
        fi
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
    gnupg # gpg 命令（签名/加密）

    # 开发语言/工具链（系统级）
    rust-bin.stable.latest.default
    rust-bin.stable.latest.rust-analyzer
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
    python3Packages.pip
    pyright
    ruff
    black
    uv
    lutris
  ];

  # KVM / libvirt 虚拟化
  virtualisation = {
    libvirtd = {
      enable = true;
      qemu.swtpm.enable = true;
    };

    # Docker 容器
    docker = {
      enable = true;
      enableOnBoot = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
        flags = [ "--all" ]; # 清理所有未使用的镜像（不仅悬空镜像）
      };
    };
  };

  # 修复：防止锁定模式在重启后阻断网络
  # 问题：tmpfs 根分区 + 持久化 /etc/mullvad-vpn 会保留锁定模式设置
  # 解决：启动时强制禁用锁定模式，避免 VPN 连接失败时无网络
  systemd = {
    services.mullvad-daemon.serviceConfig = {
      ExecStartPre = pkgs.writeShellScript "disable-mullvad-lockdown" ''
        settings_file="/etc/mullvad-vpn/settings.json"
        if [ -f "$settings_file" ]; then
          ${pkgs.jq}/bin/jq '.block_when_disconnected = false' "$settings_file" > "$settings_file.tmp"
          mv "$settings_file.tmp" "$settings_file"
          echo "Mullvad lockdown mode 已禁用（防止启动阻断网络）"
        fi
      '';
    };

    # 定期清理临时文件（模拟部分 tmpfs 优势）
    tmpfiles.rules = [
      # 确保持久化密码文件权限正确（存在时修正，不创建）
      "z /persistent/etc/user-password 0600 root root -"
      "z /persistent/etc/root-password 0600 root root -"
      # 7天清理缓存
      "e ${homeDir}/.cache - - - 7d"
      # 清理临时文件
      "e /tmp - - - 1d"
      "e /var/tmp - - - 7d"
      # 可选：清理特定应用缓存（取消注释以启用）
      # "e /home/${mainUser}/.cache/mozilla - - - 3d"
      # "e /home/${mainUser}/.cache/chromium - - - 3d"
      # "e /home/${mainUser}/.cache/thumbnails - - - 7d"
    ];
  };
}
