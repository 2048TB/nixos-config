{ config, pkgs, lib, myvars, mainUser, preservation, ... }:
let
  # 系统常量
  defaultUid = 1000;
  defaultGid = 1000;
  gcRetentionDays = "7d";
  gnupgCacheTtlSeconds = 4 * 60 * 60; # 4 小时
  homeDir = "/home/${mainUser}";

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
      "/var/cache/mullvad-vpn" # relay 列表缓存（避免重启后重新下载）
      "/var/lib/flatpak"
    ];
    files = [
      {
        file = "/etc/machine-id";
        inInitrd = true;
      }
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


  # flake.nix 的 allowUnfree 仅影响 flake 上下文，模块内仍需显式配置
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

      # 仅信任 root（@wheel 可通过恶意 substituter 提权，已移除）
      trusted-users = [ "root" ];

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

  security = {
    apparmor = {
      enable = true;

      # 强制终止未被约束但已有配置文件的进程，避免部分程序绕过策略
      killUnconfinedConfinables = true;
      packages = with pkgs; [
        apparmor-utils
        apparmor-profiles
      ];
    };

    polkit = {
      enable = true;
      # 允许 wheel 组用户挂载/卸载外部存储设备（仅限 mount 类操作）
      extraConfig = ''
        polkit.addRule(function(action, subject) {
          if (
            subject.isInGroup("wheel")
            && (
              action.id == "org.freedesktop.udisks2.filesystem-mount" ||
              action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||
              action.id == "org.freedesktop.udisks2.filesystem-mount-other-seat" ||
              action.id == "org.freedesktop.udisks2.filesystem-unmount-others" ||
              action.id == "org.freedesktop.udisks2.encrypted-unlock" ||
              action.id == "org.freedesktop.udisks2.encrypted-lock-others" ||
              action.id == "org.freedesktop.udisks2.loop-setup" ||
              action.id == "org.freedesktop.udisks2.power-off-drive"
            )
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
      hashedPassword = myvars.rootPasswordHash;
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
      ];
      shell = pkgs.zsh;
      hashedPassword = myvars.userPasswordHash;
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

    # Mullvad 依赖 systemd-resolved 管理 DNS 分流（防止 VPN 连接后 DNS 泄漏）
    resolved.enable = true;

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
  assertions = [
    {
      assertion = myvars ? userPasswordHash && myvars.userPasswordHash != "CHANGE_ME";
      message = "Set myvars.userPasswordHash in flake.nix (use mkpasswd -m sha-512).";
    }
    {
      assertion = myvars ? rootPasswordHash && myvars.rootPasswordHash != "CHANGE_ME";
      message = "Set myvars.rootPasswordHash in flake.nix (use mkpasswd -m sha-512).";
    }
  ];

  systemd = {
    services = {
      systemd-machine-id-commit.enable = false;

      create-swapfile = {
        description = "Create Btrfs swapfile if missing";
        after = [ "local-fs.target" ];
        before = [ "swap.target" ];
        wantedBy = [ "swap.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          if [ ! -f /swap/swapfile ]; then
            ${pkgs.btrfs-progs}/bin/btrfs filesystem mkswapfile \
              --size ${toString myvars.swapSizeGb}g \
              --uuid clear \
              /swap/swapfile
            chmod 600 /swap/swapfile
          fi
        '';
      };

      mullvad-daemon.serviceConfig = {
        ExecStartPre = pkgs.writeShellScript "disable-mullvad-lockdown" ''
          settings_file="/etc/mullvad-vpn/settings.json"
          if [ -f "$settings_file" ]; then
            if ${pkgs.jq}/bin/jq '.block_when_disconnected = false | .auto_connect = false' "$settings_file" > "$settings_file.tmp"; then
              mv "$settings_file.tmp" "$settings_file"
              echo "Mullvad lockdown mode 已禁用（防止启动阻断网络）"
            else
              rm -f "$settings_file.tmp"
              echo "WARNING: Failed to update Mullvad settings (invalid JSON). Keeping existing file." >&2
            fi
          fi
        '';
      };

      # mullvad-network-safety 已移除：ExecStartPre 已在 daemon 启动前禁用 lockdown mode
    };

    # 定期清理临时文件（模拟部分 tmpfs 优势）
    tmpfiles.rules = [
      "d /persistent/nixos-config 0755 root root -"
      # Keep a stable entrypoint; /etc/nixos is a symlink to persistent config.
      # This relies on /persistent being mounted early (neededForBoot=true).
      "L+ /etc/nixos - - - - /persistent/nixos-config"
      # 30天清理缓存（浏览器/shader/包管理器缓存需要较长保留期）
      "e ${homeDir}/.cache - - - 30d"
      # 清理临时文件
      "e /tmp - - - 1d"
      "e /var/tmp - - - 7d"
    ];
  };
}
