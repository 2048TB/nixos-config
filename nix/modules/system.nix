{ config
, pkgs
, lib
, myvars
, mainUser
, sharedPortalConfig
, ...
}:
let
  # 系统常量
  defaultUid = 1000;
  defaultGid = 1000;
  gnupgCacheTtlSeconds = 4 * 60 * 60; # 4 小时
  homeDir = "/home/${mainUser}";
  # 修复目录所有权的通用 activation script 生成器
  mkFixOwnershipScript = targetDir: {
    text = ''
      if [ -d "${targetDir}" ] && id -u ${mainUser} >/dev/null 2>&1; then
        marker_root="/persistent/.nixos-activation/ownership-fix"
        marker_name="$(printf '%s' "${targetDir}" | tr '/ ' '__')"
        current_uid=$(stat -c %u "${targetDir}" 2>/dev/null || echo "")
        current_gid=$(stat -c %g "${targetDir}" 2>/dev/null || echo "")
        target_uid=$(id -u ${mainUser})
        target_gid=$(id -g ${mainUser})
        marker_file="$marker_root/$marker_name.uid$target_uid.gid$target_gid.done"
        if [ ! -f "$marker_file" ]; then
          if [ -n "$current_uid" ] && [ -n "$current_gid" ] && { [ "$current_uid" != "$target_uid" ] || [ "$current_gid" != "$target_gid" ]; }; then
            find "${targetDir}" -xdev \( -not -user ${mainUser} -o -not -group ${mainUser} \) \
              -exec chown ${mainUser}:${mainUser} {} + || true
          fi
          mkdir -p "$marker_root"
          touch "$marker_file"
        fi
      fi
    '';
    deps = [ "users" ];
  };
  # 仅将 MinGW 交叉编译器的可执行文件加入 system path，避免与本机 gcc 的文档路径冲突告警。
  mingwToolchainBinOnly = pkgs.buildEnv {
    name = "mingw-w64-toolchain-bin-only";
    paths = [ pkgs.pkgsCross.mingwW64.stdenv.cc ];
    pathsToLink = [ "/bin" ];
  };
  # 部分 Electron 应用（如 Mullvad）会在空 PATH 环境里调用 `gsettings`。
  # NixOS 下 /bin/sh 默认 PATH 为 /no-such-path，需要提供兼容入口并补齐 schema 路径。
  gsettingsCompatWrapper = pkgs.writeShellScript "gsettings-compat" ''
    export GSETTINGS_SCHEMA_DIR="${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas"
    exec ${pkgs.glib}/bin/gsettings "$@"
  '';
  mkLogFilteredScript =
    name: executable: filters:
    let
      mkSedDeleteExpr = pattern:
        let
          escapedPattern = lib.replaceStrings [ "/" ] [ "\\/" ] pattern;
        in
        "/${escapedPattern}/d";
      sedDeleteArgs =
        lib.concatMapStringsSep " \\\n"
          (pattern: "          -e ${lib.escapeShellArg (mkSedDeleteExpr pattern)}")
          filters;
    in
    pkgs.writeShellScript name ''
            set -euo pipefail
            sedBin="${pkgs.gnused}/bin/sed"

            set +e
            ${executable} "$@" 2>&1 \
              | "$sedBin" -u -E \
      ${sedDeleteArgs}
              >&2
            status="''${PIPESTATUS[0]}"
            set -e
            exit "$status"
    '';
  wireplumberQuietLauncher = mkLogFilteredScript "wireplumber-quiet-launcher" "${pkgs.wireplumber}/bin/wireplumber" [
    "wp_event_dispatcher_unregister_hook: assertion 'already_registered_dispatcher == self' failed"
    "wp-event-dispatcher: wp_event_dispatcher_unregister_hook: assertion 'already_registered_dispatcher == self' failed"
    "wp-event-dispatcher: <WpAsyncEventHook:.*> failed: failed to activate item: Object activation aborted: proxy destroyed"
  ];
  cpuVendor = myvars.cpuVendor or "auto";
  hasAmd = cpuVendor != "intel";
  hasIntel = cpuVendor != "amd";
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
  enableHibernate = myvars.enableHibernate or true;
  resumeDevice =
    if config.fileSystems ? "/swap" && config.fileSystems."/swap" ? device
    then config.fileSystems."/swap".device
    else "/dev/mapper/crypted-nixos";
  resumeKernelParams =
    if enableHibernate && myvars ? resumeOffset && myvars.resumeOffset != null
    then [ "resume_offset=${toString myvars.resumeOffset}" ]
    else [ ];
  roleFlags = import ./system/role-flags.nix { inherit myvars; };
  inherit (roleFlags) enableMullvadVpn enableLibvirtd enableDocker enableFlatpak useRootfulDocker;
  rootTmpfsSize = myvars.rootTmpfsSize or "2G";
  journaldSystemMaxUse = myvars.journaldSystemMaxUse or "512M";
  journaldRuntimeMaxUse = myvars.journaldRuntimeMaxUse or "256M";
  configRepoPath = myvars.configRepoPath or "/persistent/nixos-config";
  enableAggressiveApparmorKill = myvars.enableAggressiveApparmorKill or false;
  portalConfig = sharedPortalConfig;
  agenixMainKeyPath = "/persistent/keys/main.agekey";
  expectedAgenixMainPub = builtins.replaceStrings [ "\n" "\r" ] [ "" "" ] (builtins.readFile ../../secrets/keys/main.age.pub);
  agenixBootstrapSourcePaths = [
    "${configRepoPath}/.keys/main.agekey"
    "/etc/nixos/.keys/main.agekey"
    "/home/${mainUser}/nixos/.keys/main.agekey"
  ];
  ageIdentityPaths = [
    agenixMainKeyPath
    "/etc/ssh/ssh_host_ed25519_key"
    "/persistent/etc/ssh/ssh_host_ed25519_key"
  ];
  userPasswordSecretFile = ../../secrets/passwords/user-password.age;
  rootPasswordSecretFile = ../../secrets/passwords/root-password.age;
  githubSshPrivateSecretFile = ../../secrets/ssh/github_id_ed25519.age;
  githubSshPublicSecretFile = ../../secrets/ssh/github_id_ed25519.pub.age;
  hasGithubSshPrivateSecret = builtins.pathExists githubSshPrivateSecretFile;
  hasGithubSshPublicSecret = builtins.pathExists githubSshPublicSecretFile;
  tuigreetPackage = pkgs.tuigreet or pkgs.greetd.tuigreet;
  # 参考 Catppuccin + ReGreet 常见高对比方案（tuigreet 仅支持 ANSI color name）。
  tuigreetTheme =
    "border=cyan;text=white;prompt=lightcyan;time=lightblue;action=lightblue;"
    + "button=yellow;container=black;input=lightyellow;greet=cyan;title=lightcyan";
  tuigreetCommand = pkgs.writeShellScript "greetd-tuigreet-session" ''
    exec ${lib.getExe tuigreetPackage} \
      --time \
      --time-format '%a %Y-%m-%d %H:%M:%S' \
      --remember \
      --remember-session \
      --asterisks \
      --greeting 'NixOS ${myvars.hostname} login' \
      --width 92 \
      --window-padding 5 \
      --container-padding 4 \
      --prompt-padding 2 \
      --greet-align center \
      --theme '${tuigreetTheme}' \
      --power-shutdown '${pkgs.systemd}/bin/systemctl poweroff' \
      --power-reboot '${pkgs.systemd}/bin/systemctl reboot' \
      --cmd ${homeDir}/.wayland-session
  '';
in
{
  imports = [
    ./system/nix-settings.nix
    ./system/assertions.nix
    ./system/role-services.nix
  ];

  boot = {
    # 引导加载器
    loader = {
      systemd-boot = {
        enable = lib.mkDefault true;
        configurationLimit = lib.mkDefault 10;
        consoleMode = lib.mkDefault "max";
      };
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
    resumeDevice = lib.mkIf enableHibernate (lib.mkDefault resumeDevice);
    kernelParams = lib.mkIf enableHibernate resumeKernelParams;

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

    # zram 场景下的内核内存回收参数
    kernel.sysctl = {
      "vm.swappiness" = 180;
      "vm.watermark_boost_factor" = 0;
      "vm.watermark_scale_factor" = 125;
      "vm.page-cluster" = 0;
    };
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
    ]
    ++ lib.optionals enableLibvirtd [
      "/var/lib/libvirt" # 虚拟机镜像和配置
    ]
    ++ lib.optionals (enableDocker && useRootfulDocker) [
      "/var/lib/docker" # Docker 镜像、容器和卷
    ]
    ++ lib.optionals enableMullvadVpn [
      "/etc/mullvad-vpn"
      "/var/cache/mullvad-vpn" # relay 列表缓存（避免重启后重新下载）
    ]
    ++ lib.optionals enableFlatpak [
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
        "size=${rootTmpfsSize}"
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

  # 内存压缩交换：优先于磁盘 swapfile，减少高负载时的磁盘 I/O 抖动
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    priority = 100;
    memoryPercent = 50;
  };

  networking = {
    hostName = myvars.hostname;
    networkmanager.enable = true;
    firewall.enable = true;
  };

  security = {
    apparmor = {
      enable = true;

      # 仅在主机显式开启时终止未被约束但已有配置文件的进程（偏安全、可能影响稳定性）
      killUnconfinedConfinables = enableAggressiveApparmorKill;
      packages = with pkgs; [
        apparmor-utils
        apparmor-profiles
      ];
    };

    polkit = {
      enable = true;
      # 恢复单用户桌面体验：wheel 组对 UDisks 挂载类操作直接放行。
      extraConfig = ''
        polkit.addRule(function(action, subject) {
          var guardedActions = [
            "org.freedesktop.udisks2.filesystem-mount",
            "org.freedesktop.udisks2.filesystem-mount-system",
            "org.freedesktop.udisks2.filesystem-mount-other-seat",
            "org.freedesktop.udisks2.filesystem-unmount-others",
            "org.freedesktop.udisks2.encrypted-unlock",
            "org.freedesktop.udisks2.encrypted-lock-others",
            "org.freedesktop.udisks2.loop-setup",
            "org.freedesktop.udisks2.power-off-drive"
          ];
          if (subject.isInGroup("wheel") && guardedActions.indexOf(action.id) >= 0) {
            return polkit.Result.YES;
          }
        });
      '';
    };
    rtkit.enable = true;
    # 为所有 NixOS 主机启用 greetd 的 keyring PAM 自动解锁。
    pam.services.greetd.enableGnomeKeyring = true;
    # 通过 passwd 修改登录密码时，同步更新 keyring 密码，避免后续出现二次解锁提示
    pam.services.passwd.enableGnomeKeyring = true;
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
      # 已在 xdg.portal 配置中显式固定 FileChooser=gtk，无需额外依赖 Nautilus。
      useNautilus = false;
    };

    seahorse.enable = true;

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

  age = {
    identityPaths = ageIdentityPaths;
    secrets =
      {
        "passwords/user" = {
          file = userPasswordSecretFile;
          mode = "0400";
          owner = "root";
          group = "root";
        };
        "passwords/root" = {
          file = rootPasswordSecretFile;
          mode = "0400";
          owner = "root";
          group = "root";
        };
      }
      // lib.optionalAttrs hasGithubSshPrivateSecret {
        "ssh/github-private" = {
          file = githubSshPrivateSecretFile;
          path = "${homeDir}/.ssh/id_ed25519";
          symlink = false;
          mode = "0400";
          owner = mainUser;
          group = mainUser;
        };
      }
      // lib.optionalAttrs hasGithubSshPublicSecret {
        "ssh/github-public" = {
          file = githubSshPublicSecretFile;
          path = "${homeDir}/.ssh/id_ed25519.pub";
          symlink = false;
          mode = "0644";
          owner = mainUser;
          group = mainUser;
        };
      };
  };

  # 配合 tmpfs 根分区，用户数据库由配置统一管理，避免 passwd 修改丢失
  users = {
    mutableUsers = false;

    # root 账户配置（用于紧急恢复和单用户模式）
    users.root = {
      hashedPasswordFile = config.age.secrets."passwords/root".path;
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
      ];
      shell = pkgs.zsh;
      hashedPasswordFile = config.age.secrets."passwords/user".path;
    };

    defaultUserShell = pkgs.zsh;
  };

  # 默认 Shell
  environment.shells = with pkgs; [
    bashInteractive
    zsh
  ];

  services = {
    xserver.enable = false;

    greetd = {
      enable = true;
      useTextGreeter = true;
      settings.default_session = {
        # 使用 greeter 账户运行 tuigreet；认证后再启动用户会话
        user = "greeter";
        command = "${tuigreetCommand}";
      };
    };

    # 音频（含 32 位支持，便于 Steam/Proton）
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      lowLatency.enable = true;
      # 避免 xdg-desktop-portal 在实时优先级请求时打印 pidns/pidfd 报错。
      # 参考 PipeWire libpipewire-module-rt 文档：module.rt.args.rtportal.enabled
      # 注意：pipewire-pulse 会单独加载自身配置，需与 pipewire 同步关闭。
      extraConfig.pipewire."10-disable-rtportal" = {
        "module.rt.args" = {
          "rtportal.enabled" = false;
        };
      };
      extraConfig.pipewire-pulse."10-disable-rtportal" = {
        "module.rt.args" = {
          "rtportal.enabled" = false;
        };
      };
      wireplumber.extraConfig."10-disable-libcamera-monitor"."wireplumber.profiles" = {
        # libcamera monitor 在当前 wireplumber 版本会触发已知启动期告警。
        # 若未来需要 libcamera 管线，可删除该项并升级 wireplumber 后复测。
        main."monitor.libcamera" = "disabled";
      };
    };
    pulseaudio.enable = false;
    # UPower DBus 接口：WirePlumber 蓝牙电量读取 + Waybar battery 模块依赖
    upower.enable = true;

    # 文件管理常用的缩略图/挂载支持
    gvfs.enable = true;
    tumbler.enable = true;
    udisks2.enable = true; # USB 设备自动识别和挂载

    # GNOME 密钥环
    gnome.gnome-keyring.enable = true;

    journald.extraConfig = ''
      SystemMaxUse=${journaldSystemMaxUse}
      RuntimeMaxUse=${journaldRuntimeMaxUse}
    '';
  };

  # Wayland 桌面常用门户（文件选择/截图/投屏）
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    # portal 接口映射由 flake specialArgs 统一提供，避免 system/home 漂移。
    config = portalConfig;
    # 系统侧固定 GNOME backend；gtk backend 由 Home Manager 注入用户 profile。
    # 原因：当前仓库对 system/home 包重叠有校验，双侧同时声明 gtk 会触发失败。
    extraPortals = lib.mkForce (with pkgs; [
      xdg-desktop-portal-gnome
    ]);
  };

  fonts.packages = with pkgs; [
    # 编程字体
    cascadia-code
    jetbrains-mono
    fira-code
    sarasa-gothic # 更纱黑体（CJK+Latin 等宽对齐）
    maple-mono.NF-CN-unhinted # Nerd Font（含中文字形，备用）

    # Emoji
    noto-fonts-color-emoji

    # 中日韩字体
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    wqy_zenhei
  ];

  # 系统语言（中文）与 Locale 生成 + 输入法支持
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
        qt6Packages.fcitx5-chinese-addons # 中文拼音输入法（Libpinyin 引擎，nixpkgs 中该包名已迁移到 qt6Packages 命名空间）
        fcitx5-pinyin-zhwiki # 中文维基百科词库（提升识别准确率）
      ];
    };
  };

  # 首次启动时修复用户目录权限（兼容历史安装过程中的 UID 偏差）
  # 同时在激活阶段兜底创建 swapfile（仅在缺失时），避免开机阶段引入 systemd 依赖环。
  # 说明：曾出现 create-swapfile.service 与 swap.target/run-wrappers 形成 ordering cycle，
  # 导致 suid-sgid-wrappers 被跳过，进而触发 greetd 的 pam_unix helper 缺失。
  system.activationScripts = {
    # 确保在 agenix 生成与解密阶段前已准备好 identity key。
    # 避免首次/迁移时出现 "no readable identities found"。
    agenixNewGeneration.deps = lib.mkAfter [ "agenixKeyBootstrap" ];
    agenixInstall.deps = lib.mkAfter [ "agenixKeyBootstrap" ];

    agenixKeyBootstrap = {
      text = ''
        target_key="${agenixMainKeyPath}"
        if [ ! -r "$target_key" ]; then
          age_keygen_bin="${pkgs.age}/bin/age-keygen"
          install_bin="${pkgs.coreutils}/bin/install"
          mkdir_bin="${pkgs.coreutils}/bin/mkdir"
          src=""

          for candidate in ${lib.concatMapStringsSep " " lib.escapeShellArg agenixBootstrapSourcePaths}; do
            [ -r "$candidate" ] || continue
            candidate_pub="$("$age_keygen_bin" -y "$candidate" 2>/dev/null || true)"
            [ "$candidate_pub" = "${expectedAgenixMainPub}" ] || continue
            src="$candidate"
            break
          done

          if [ -z "$src" ]; then
            for candidate in /home/*/nixos/.keys/main.agekey; do
              [ -r "$candidate" ] || continue
              candidate_pub="$("$age_keygen_bin" -y "$candidate" 2>/dev/null || true)"
              [ "$candidate_pub" = "${expectedAgenixMainPub}" ] || continue
              src="$candidate"
              break
            done
          fi

          if [ -n "$src" ]; then
            "$mkdir_bin" -p /persistent/keys
            "$install_bin" -D -m 0400 -o root -g root "$src" "$target_key"
            echo "[agenix] bootstrapped main identity key: $src -> $target_key"
          else
            echo "[agenix] WARNING: main identity key missing at $target_key and no bootstrap source found." >&2
          fi
        fi
      '';
      deps = [ "specialfs" ];
    };

    ensureUserSshDir = {
      text = ''
        if id -u ${mainUser} >/dev/null 2>&1; then
          install -d -m 0700 -o ${mainUser} -g ${mainUser} ${homeDir}/.ssh
        fi
      '';
      deps = [ "users" ];
    };

    createSwapfileIfMissing = {
      text = ''
        if [ -d /swap ] && [ ! -f /swap/swapfile ]; then
          ${pkgs.btrfs-progs}/bin/btrfs filesystem mkswapfile \
            --size ${toString myvars.swapSizeGb}g \
            --uuid clear \
            /swap/swapfile
          chmod 600 /swap/swapfile
        fi
      '';
      deps = [ "specialfs" ];
    };

    warnMissingResumeOffset = {
      text = ''
        if [ "${if enableHibernate then "1" else "0"}" = "1" ] && [ -f /swap/swapfile ] && [ -z "${if myvars ? resumeOffset && myvars.resumeOffset != null then toString myvars.resumeOffset else ""}" ]; then
          echo "WARNING: myvars.resumeOffset is not set on host ${myvars.hostname}." >&2
          echo "WARNING: hibernate may power off without resuming previous session." >&2
          echo "WARNING: run (as root): btrfs inspect-internal map-swapfile -r /swap/swapfile" >&2
        fi
      '';
      deps = [ "specialfs" ];
    };

    warnSwapfileSizeMismatch = {
      text = ''
        if [ "${if enableHibernate then "1" else "0"}" = "1" ] && [ -f /swap/swapfile ]; then
          current_size_bytes="$(${pkgs.coreutils}/bin/stat -c %s /swap/swapfile 2>/dev/null || echo 0)"
          target_size_bytes=$(( ${toString myvars.swapSizeGb} * 1024 * 1024 * 1024 ))
          if [ "$current_size_bytes" -ne "$target_size_bytes" ]; then
            echo "WARNING: /swap/swapfile size ($current_size_bytes bytes) != configured ${toString myvars.swapSizeGb}GiB ($target_size_bytes bytes) on host ${myvars.hostname}." >&2
            echo "WARNING: recreate swapfile and refresh myvars.resumeOffset before relying on hibernate." >&2
          fi
        fi
      '';
      deps = [ "specialfs" ];
    };

    warnResumeOffsetMismatch = {
      text = ''
          configured_resume_offset="${if myvars ? resumeOffset && myvars.resumeOffset != null then toString myvars.resumeOffset else ""}"
          if [ "${if enableHibernate then "1" else "0"}" = "1" ] && [ -f /swap/swapfile ] && [ -n "$configured_resume_offset" ]; then
            btrfs_bin="${pkgs.btrfs-progs}/bin/btrfs"
            head_bin="${pkgs.coreutils}/bin/head"
            actual_resume_offset="$("$btrfs_bin" inspect-internal map-swapfile -r /swap/swapfile 2>/dev/null | "$head_bin" -n 1 || true)"
            case "$actual_resume_offset" in
              ""|*[!0-9]*)
                ;;
              *)
                if [ "$actual_resume_offset" != "$configured_resume_offset" ]; then
                  echo "WARNING: myvars.resumeOffset ($configured_resume_offset) != actual swapfile resume offset ($actual_resume_offset) on host ${myvars.hostname}." >&2
                  echo "WARNING: update hosts/nixos/${myvars.hostname}/vars.nix: resumeOffset = $actual_resume_offset;" >&2
                fi
                ;;
            esac
        fi
      '';
      deps = [ "specialfs" ];
    };

    fixUserHomePerms = mkFixOwnershipScript homeDir;

    # 确保持久化配置仓库归属普通用户，避免 Git safe.directory/写权限问题
    fixPersistentConfigRepoPerms = mkFixOwnershipScript configRepoPath;
  };

  # 时区
  time.timeZone = myvars.timezone;

  # 系统级最小软件
  environment.systemPackages = with pkgs; [
    # 编辑器（vim 由 home-manager 配置，此处仅保留 neovim 作为 root 用户编辑器）
    neovim

    # 开发语言/工具链（系统级）
    # Rust: 预装 Windows GNU target，支持在 Linux 主机交叉编译 .exe
    (rust-bin.stable.latest.default.override {
      targets = [ "x86_64-pc-windows-gnu" ];
    })
    rust-bin.stable.latest.rust-analyzer
    # MinGW 交叉工具链：为 x86_64-pc-windows-gnu 提供 linker（x86_64-w64-mingw32-gcc）
    mingwToolchainBinOnly
    zig
    zls
    go
    gcc # cgo 依赖本机 C 编译器（gcc）
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
    # Niri 官方要求：xwayland-satellite 需在 PATH 中，供 XWayland 应用桥接。
    xwayland-satellite
  ];

  systemd = {
    services = {
      systemd-machine-id-commit.enable = false;

      # 禁用 NetworkManager-wait-online：该服务在网络不可用时阻塞启动（最多 30s 超时）
      # 在 nsncd 失败导致名称解析不可用时尤其严重，会造成级联等待
      NetworkManager-wait-online.enable = false;

      mullvad-daemon = lib.mkIf enableMullvadVpn {
        serviceConfig = {
          ExecStartPre = pkgs.writeShellScript "disable-mullvad-lockdown" ''
            settings_dir="/etc/mullvad-vpn"
            settings_file="$settings_dir/settings.json"
            mkdir -p "$settings_dir"
            if [ ! -f "$settings_file" ]; then
              echo '{}' > "$settings_file"
            fi

            if ${pkgs.jq}/bin/jq '.block_when_disconnected = false | .auto_connect = true' "$settings_file" > "$settings_file.tmp"; then
              mv "$settings_file.tmp" "$settings_file"
              echo "Mullvad autoconnect 已启用，lockdown mode 已禁用"
            else
              rm -f "$settings_file.tmp"
              echo "WARNING: Failed to update Mullvad settings (invalid JSON). Keeping existing file." >&2
            fi
          '';
        };
      };

      # mullvad-network-safety 已移除：ExecStartPre 已在 daemon 启动前禁用 lockdown mode

      # nsncd 修复：tmpfs root 下 /var/run 可能被其他服务提前创建为目录（非符号链接）
      # 导致 nsncd 无法在 /var/run/nscd/socket 创建套接字
      # 参考：https://github.com/NixOS/nixpkgs/issues/432251
      nscd = {
        after = [ "systemd-tmpfiles-setup.service" ];
        wants = [ "systemd-tmpfiles-setup.service" ];
      };

      # 在 greetd 场景下提前拉起 upower，避免用户会话早期 UPower 尚未激活
      # 导致 wireplumber 打印 "Failed to get percentage from UPower: NameHasNoOwner"
      upower.wantedBy = [ "multi-user.target" ];
    };

    user.services = {
      # systemd override 中需先清空原 ExecStart，再设置 wrapper；
      # 否则与上游 unit 的 ExecStart 并存，导致 bad-setting。
      wireplumber.serviceConfig.ExecStart = lib.mkForce [
        ""
        "${wireplumberQuietLauncher}"
      ];
    };

    # 定期清理临时文件（模拟部分 tmpfs 优势）
    tmpfiles.rules = [
      # 修复 tmpfs root 下 /var/run 竞态：确保为 /run 的符号链接
      "L+ /var/run - - - - /run"
      # 兼容硬编码 shebang（#!/bin/bash）的第三方脚本
      "L+ /bin/bash - - - - /run/current-system/sw/bin/bash"
      # Mullvad GUI 上游在 Linux 中以精简 env 调用 `gsettings`，并丢失 PATH。
      # NixOS 的 /bin/sh 在 PATH 未设置时默认 /no-such-path，因此同时提供 /usr/bin 与 /no-such-path 入口。
      "d /no-such-path 0755 root root -"
      "L+ /usr/bin/gsettings - - - - ${gsettingsCompatWrapper}"
      "L+ /no-such-path/gsettings - - - - ${gsettingsCompatWrapper}"
      "d ${configRepoPath} 0755 ${mainUser} ${mainUser} -"
      # Keep a stable entrypoint; /etc/nixos is a symlink to persistent config.
      # This relies on /persistent being mounted early (neededForBoot=true).
      "L+ /etc/nixos - - - - ${configRepoPath}"
      # 30天清理缓存（浏览器/shader/包管理器缓存需要较长保留期）
      "e ${homeDir}/.cache - - - 30d"
      # 清理临时文件
      "e /tmp - - - 1d"
      "e /var/tmp - - - 7d"
    ];
  };
}
