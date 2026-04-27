{ lib
, mylib
, pkgs
, name
, mainUser
, nixosSystem
, expectedLuksName ? null
, expectedVideoDrivers ? null
, expectedResumeOffset ? null
, expectedHostname ? name
, expectedDockerMode ? null
, expectedTrustedUsers ? null
, expectedTrustedSubstituters ? null
, expectedKvmModules ? null
, cpuVendor ? null
, ...
}:
let
  nixCache = import ../../../lib/nix-cache.nix;
  inherit (nixCache) cacheSubstituters trustedUsers;
  cfg = nixosSystem.config;
  hostCfg = cfg.my.host;
  hostRoles = hostCfg.roles or [ ];
  hasGamingRole = builtins.elem "gaming" hostRoles;
  secureBootEnabled = hostCfg.secureBoot.enable or false;
  hasDesktopSession = cfg.my.capabilities.hasDesktopSession or false;
  hasGpuVendor = vendor: builtins.elem vendor hostCfg.gpuVendors;
  hasExpectedGpuVendorsForMode =
    if hostCfg.gpuMode == "none" then hostCfg.gpuVendors == [ ]
    else if hostCfg.gpuMode == "modesetting" then !(hasGpuVendor "amd") && !(hasGpuVendor "nvidia")
    else if hostCfg.gpuMode == "amdgpu" then (hasGpuVendor "amd") && !(hasGpuVendor "nvidia")
    else if hostCfg.gpuMode == "nvidia" then (hasGpuVendor "nvidia") && !(hasGpuVendor "amd")
    else if hostCfg.gpuMode == "amd-nvidia-hybrid" then (hasGpuVendor "amd") && (hasGpuVendor "nvidia")
    else false;
  declaredPrimaryDisplays = builtins.filter (display: display.primary or false) hostCfg.displays;
  hasExpectedPrimaryDisplayCount =
    hostCfg.displays == [ ] || builtins.length declaredPrimaryDisplays == 1;
  hasExpectedDesktopMetadata =
    (hostCfg.desktopSession && hostCfg.desktopProfile != "none")
    || (!hostCfg.desktopSession && hostCfg.desktopProfile == "none");
  hasExpectedHybridMetadata =
    hostCfg.gpuMode != "amd-nvidia-hybrid"
    || (hostCfg.amdgpuBusId != null && hostCfg.nvidiaBusId != null);
  hasExpectedGamingRoleMetadata =
    !hasGamingRole || hostCfg.desktopSession;
  resolvedExpectedLuksName =
    if expectedLuksName != null then expectedLuksName else hostCfg.luksName;
  resolvedExpectedResumeOffset =
    if expectedResumeOffset != null then expectedResumeOffset else hostCfg.resumeOffset or null;
  resolvedExpectedTrustedUsers =
    if expectedTrustedUsers != null then expectedTrustedUsers else trustedUsers;
  resolvedExpectedVideoDrivers =
    if expectedVideoDrivers != null then
      expectedVideoDrivers
    else if !hasDesktopSession then
      null
    else if hostCfg.gpuMode == "nvidia" then
      [ "nvidia" ]
    else if hostCfg.gpuMode == "amdgpu" then
      [ "amdgpu" ]
    else if hostCfg.gpuMode == "amd-nvidia-hybrid" then
      [ "nvidia" "amdgpu" ]
    else
      [ "modesetting" ];
  resolvedExpectedDockerMode =
    if expectedDockerMode != null then
      expectedDockerMode
    else if builtins.elem "container" hostRoles then
      hostCfg.dockerMode or "rootless"
    else
      "disabled";

  resolvedExpectedKvmModules =
    if expectedKvmModules != null then expectedKvmModules
    else if cpuVendor != null then mylib.kvmModulesForVendor cpuVendor
    else null;
  expectedDisplayManagerSessionNames = lib.optionals hasDesktopSession [
    hostCfg.desktopProfile
  ];
  hasVpnRole = builtins.elem "vpn" hostRoles;
  hmCfg = cfg.home-manager.users.${mainUser};
  expectedHome = "/home/${mainUser}";
  preservedDirectories = cfg.preservation.preserveAt."/persistent".directories or [ ];
  preservedDirectoryPaths = map (entry: entry.directory or entry) preservedDirectories;

  getNames = pkgList: lib.unique (map (pkg: builtins.unsafeDiscardStringContext (lib.getName pkg)) pkgList);
  excludeAllowed = allowed: names: builtins.filter (n: !(builtins.elem n allowed)) names;

  allSystemPackageOutPaths = map (pkg: pkg.outPath) cfg.environment.systemPackages;
  systemPackageOutPaths = lib.unique allSystemPackageOutPaths;
  homePackageOutPaths = lib.unique (map (pkg: pkg.outPath) hmCfg.home.packages);
  systemHomeOverlapOutPaths = lib.intersectLists systemPackageOutPaths homePackageOutPaths;
  systemHomeOverlapPkgs =
    lib.filter (pkg: builtins.elem pkg.outPath systemHomeOverlapOutPaths) cfg.environment.systemPackages;
  systemHomeOverlapNames = getNames systemHomeOverlapPkgs;
  systemPackageNames = getNames cfg.environment.systemPackages;
  systemPackageByName = packageName:
    let
      matches = builtins.filter
        (pkg: builtins.unsafeDiscardStringContext (lib.getName pkg) == packageName)
        cfg.environment.systemPackages;
    in
    if matches == [ ] then
      pkgs.runCommand "missing-${packageName}" { } ''
        mkdir -p "$out/bin"
        : > "$out/bin/${packageName}"
      ''
    else
      builtins.head matches;
  homePackageNames = getNames hmCfg.home.packages;
  homeZellijPackages = builtins.filter (pkg: lib.getName pkg == "zellij") hmCfg.home.packages;
  homeZellijOutPaths = map (pkg: pkg.outPath) homeZellijPackages;
  expectedZellijOutPath = pkgs.unstable.zellij.outPath;
  hasExpectedZellijPackage =
    pkgs.zellij.outPath == expectedZellijOutPath
    && homeZellijOutPaths == [ expectedZellijOutPath ];
  unexpectedOverlapByName = lib.intersectLists systemPackageNames homePackageNames;
  outPathKey = builtins.unsafeDiscardStringContext;
  systemDuplicateOutPaths =
    builtins.attrNames (
      lib.filterAttrs
        (_outPath: instances: builtins.length instances > 1)
        (builtins.groupBy outPathKey allSystemPackageOutPaths)
    );
  systemDuplicatePkgs =
    lib.filter
      (pkg: builtins.elem (outPathKey pkg.outPath) systemDuplicateOutPaths)
      cfg.environment.systemPackages;
  systemDuplicateNames = getNames systemDuplicatePkgs;
  # 当前各主机（按 outPath 语义）真实出现的重复项白名单。
  # 保持最小集合；新增项前应先定位上游来源并记录理由。
  allowedSystemDuplicateNames = [
    "dosfstools" # 磁盘/恢复工具链的交叉依赖
    "fuse" # 用户态文件系统依赖链
    "gnome-keyring" # 桌面与 secrets 依赖链
    "iptables" # firewall/container 栈中的兼容工具
    "less" # 显式工具与传递依赖并存
    "niri" # compositor 依赖链与显式声明并存
    "shadow" # 用户管理工具链依赖
    "zsh" # 默认 shell 与显式工具链并存
  ];
  unexpectedSystemDuplicateNames = excludeAllowed allowedSystemDuplicateNames systemDuplicateNames;
  # 当前各主机 system/home 真实重叠项白名单（按 outPath 与 by-name 双重检查）。
  # 保持最小集合，避免“误放行”掩盖新增漂移。
  allowedSystemHomeOverlapNames = [
    "man-db"
    "nix-zsh-completions"
    "shared-mime-info"
    "xdg-desktop-portal"
    "xdg-desktop-portal-gtk"
    "zsh"
  ];
  unexpectedSystemHomeOverlapNames = excludeAllowed allowedSystemHomeOverlapNames systemHomeOverlapNames;
  unexpectedOverlapByNameFiltered = excludeAllowed allowedSystemHomeOverlapNames unexpectedOverlapByName;

  expectedResumeKernelParam =
    if resolvedExpectedResumeOffset == null then null else "resume_offset=${toString resolvedExpectedResumeOffset}";
  expectsHibernate = resolvedExpectedResumeOffset != null;
  hasResumeKernelParam =
    builtins.any (param: lib.hasPrefix "resume=" param) cfg.boot.kernelParams;
  hasExpectedResumeKernelParam =
    if expectedResumeKernelParam == null then true else builtins.elem expectedResumeKernelParam cfg.boot.kernelParams;
  hasExpectedResumeKernelParamState =
    if expectsHibernate then hasResumeKernelParam else !hasResumeKernelParam;
  hasExpectedResumeOffsetKernelParamState =
    if expectsHibernate then hasExpectedResumeKernelParam else !(
      builtins.any (param: lib.hasPrefix "resume_offset=" param) cfg.boot.kernelParams
    );
  hasExpectedResumeDeviceState =
    if expectsHibernate then (cfg.boot.resumeDevice or "") != "" else (cfg.boot.resumeDevice or "") == "";
  hasExpectedAcceptFlakeConfig =
    !(cfg.nix.settings.accept-flake-config or false);
  resolvedExpectedTrustedSubstituters =
    if expectedTrustedSubstituters != null then
      expectedTrustedSubstituters
    else
      cacheSubstituters;
  sortedTrustedUsers = builtins.sort builtins.lessThan (cfg.nix.settings.trusted-users or [ ]);
  sortedExpectedTrustedUsers = builtins.sort builtins.lessThan resolvedExpectedTrustedUsers;
  hasExpectedTrustedUsers = sortedTrustedUsers == sortedExpectedTrustedUsers;
  sortedTrustedSubstituters = builtins.sort builtins.lessThan (cfg.nix.settings.trusted-substituters or [ ]);
  sortedExpectedTrustedSubstituters =
    if resolvedExpectedTrustedSubstituters == null then [ ]
    else builtins.sort builtins.lessThan resolvedExpectedTrustedSubstituters;
  hasExpectedTrustedSubstituters =
    if resolvedExpectedTrustedSubstituters == null then true
    else sortedTrustedSubstituters == sortedExpectedTrustedSubstituters;
  actualDockerMode =
    if (cfg.virtualisation.docker.rootless.enable or false)
    then "rootless"
    else if (cfg.virtualisation.docker.enable or false)
    then "rootful"
    else "disabled";
  hasExpectedDockerMode = actualDockerMode == resolvedExpectedDockerMode;
  expectsRootlessDockerLinger = resolvedExpectedDockerMode == "rootless";
  hasExpectedRootlessDockerLinger =
    if expectsRootlessDockerLinger
    then (cfg.users.users.${mainUser}.linger or false)
    else true;
  actualKvmModules = builtins.filter (m: lib.hasPrefix "kvm-" m) cfg.boot.kernelModules;
  sessionVariables = hmCfg.home.sessionVariables or { };
  hasGlobalMlRuntimeLibraryPath = builtins.hasAttr "LD_LIBRARY_PATH" sessionVariables;
  hasGlobalOpenSslBuildEnv =
    builtins.any
      (name': builtins.hasAttr name' sessionVariables)
      [
        "OPENSSL_INCLUDE_DIR"
        "OPENSSL_LIB_DIR"
        "OPENSSL_DIR"
      ];
  miseAutoUpgradeEnabled = cfg.my.host.miseAutoUpgrade or false;
  aria2EnableRpc = cfg.my.host.aria2.enableRpc or true;
  aria2RpcSecretPath = cfg.my.host.aria2.rpcSecretPath or mylib.hostMetaSchema.defaultAria2RpcSecretPath;
  hasMiseUpgradeTimer = hmCfg.systemd.user.timers ? mise-upgrade;
  tmpfilesRules = cfg.systemd.tmpfiles.rules or [ ];
  hasBinBashTmpfilesLink =
    builtins.elem "d /bin 0755 root root -" tmpfilesRules
    && builtins.elem "L+ /bin/bash - - - - /run/current-system/sw/bin/bash" tmpfilesRules;
  hasLegacyBinBashActivation = cfg.system.activationScripts ? binbash;
  swapfileResumeCheckEnabled = cfg.systemd.services ? swapfile-resume-check;
  niriConfigSource = hmCfg.xdg.configFile."niri/config.kdl".source or null;
  codeWrapperSource = hmCfg.home.file.".local/bin/code".source or null;
  antigravityWrapperSource = hmCfg.home.file.".local/bin/antigravity".source or null;

  mkNonEmptyCheck = name': items: msg:
    pkgs.runCommand name' { } ''
      if [ ${toString (builtins.length items)} -ne 0 ]; then
        echo "${msg}: ${lib.concatStringsSep ", " items}" >&2
        exit 1
      fi
      touch "$out"
    '';
in
{
  "eval-${name}-impermanence-flag" = pkgs.runCommand "eval-${name}-impermanence-flag" { } ''
    test "${if cfg.preservation.enable then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-luks-name" = pkgs.runCommand "eval-${name}-luks-name" { } ''
    test "${cfg.my.host.luksName}" = "${resolvedExpectedLuksName}"
    touch "$out"
  '';

  "eval-${name}-hostname" = pkgs.runCommand "eval-${name}-hostname" { } ''
    test "${cfg.networking.hostName}" = "${name}"
    touch "$out"
  '';

  "eval-${name}-config-repo-path" = pkgs.runCommand "eval-${name}-config-repo-path" { } ''
    test -n "${hostCfg.configRepoPath}"
    test "${cfg.programs.nh.flake}" = "${hostCfg.configRepoPath}"
    test "${if builtins.elem "d ${hostCfg.configRepoPath} 0755 ${mainUser} ${mainUser} -" tmpfilesRules then "1" else "0"}" = "1"
    test "${if builtins.elem "L+ /etc/nixos - - - - ${hostCfg.configRepoPath}" tmpfilesRules then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-host-kind" = pkgs.runCommand "eval-${name}-host-kind" { } ''
    case "${cfg.my.host.kind}" in
      workstation|server|vm) ;;
      *)
        echo "unexpected host kind: ${cfg.my.host.kind}" >&2
        exit 1
        ;;
    esac
    touch "$out"
  '';

  "eval-${name}-host-form-factor" = pkgs.runCommand "eval-${name}-host-form-factor" { } ''
    case "${cfg.my.host.formFactor}" in
      desktop|laptop|handheld|headless) ;;
      *)
        echo "unexpected host formFactor: ${cfg.my.host.formFactor}" >&2
        exit 1
        ;;
    esac
    touch "$out"
  '';

  "eval-${name}-host-tags" = pkgs.runCommand "eval-${name}-host-tags" { } ''
    test "${if lib.hasPrefix "[" (builtins.toJSON cfg.my.host.tags) then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-host-gpu-vendors" = pkgs.runCommand "eval-${name}-host-gpu-vendors" { } ''
    test "${if lib.hasPrefix "[" (builtins.toJSON cfg.my.host.gpuVendors) then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-host-gpu-mode-vendors" = pkgs.runCommand "eval-${name}-host-gpu-mode-vendors" { } ''
    if [ "${if hasExpectedGpuVendorsForMode then "1" else "0"}" != "1" ]; then
      echo "host ${name}: gpuMode=${hostCfg.gpuMode} is incompatible with gpuVendors=${builtins.toJSON hostCfg.gpuVendors}" >&2
      exit 1
    fi
    touch "$out"
  '';

  "eval-${name}-host-desktop-metadata" = pkgs.runCommand "eval-${name}-host-desktop-metadata" { } ''
    if [ "${if hasExpectedDesktopMetadata then "1" else "0"}" != "1" ]; then
      echo "host ${name}: desktopSession=${toString hostCfg.desktopSession} requires matching desktopProfile metadata, got ${hostCfg.desktopProfile}" >&2
      exit 1
    fi
    touch "$out"
  '';

  "eval-${name}-host-hybrid-gpu-metadata" = pkgs.runCommand "eval-${name}-host-hybrid-gpu-metadata" { } ''
    if [ "${if hasExpectedHybridMetadata then "1" else "0"}" != "1" ]; then
      echo "host ${name}: gpuMode=amd-nvidia-hybrid requires amdgpuBusId and nvidiaBusId" >&2
      exit 1
    fi
    touch "$out"
  '';

  "eval-${name}-host-primary-display-count" = pkgs.runCommand "eval-${name}-host-primary-display-count" { } ''
    if [ "${if hasExpectedPrimaryDisplayCount then "1" else "0"}" != "1" ]; then
      echo "host ${name}: displays must declare exactly one primary=true entry when display metadata exists" >&2
      exit 1
    fi
    touch "$out"
  '';

  "eval-${name}-host-role-metadata" = pkgs.runCommand "eval-${name}-host-role-metadata" { } ''
    if [ "${if hasExpectedGamingRoleMetadata then "1" else "0"}" != "1" ]; then
      echo "host ${name}: role 'gaming' requires desktopSession=true" >&2
      exit 1
    fi
    touch "$out"
  '';

  "eval-${name}-capability-kind" = pkgs.runCommand "eval-${name}-capability-kind" { } ''
    test "${if cfg.my.capabilities.isWorkstation == (cfg.my.host.kind == "workstation") then "1" else "0"}" = "1"
    test "${if cfg.my.capabilities.isServer == (cfg.my.host.kind == "server") then "1" else "0"}" = "1"
    test "${if cfg.my.capabilities.isVm == (cfg.my.host.kind == "vm") then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-capability-form-factor" = pkgs.runCommand "eval-${name}-capability-form-factor" { } ''
    test "${if cfg.my.capabilities.isDesktop == (cfg.my.host.formFactor == "desktop") then "1" else "0"}" = "1"
    test "${if cfg.my.capabilities.isLaptop == (cfg.my.host.formFactor == "laptop") then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-capability-desktop-session" = pkgs.runCommand "eval-${name}-capability-desktop-session" { } ''
    test "${if cfg.my.capabilities.hasDesktopSession == cfg.my.host.desktopSession then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-capability-gpu" = pkgs.runCommand "eval-${name}-capability-gpu" { } ''
    test "${if cfg.my.capabilities.hasAmdGpu == (builtins.elem "amd" cfg.my.host.gpuVendors) then "1" else "0"}" = "1"
    test "${if cfg.my.capabilities.hasIntelGpu == (builtins.elem "intel" cfg.my.host.gpuVendors) then "1" else "0"}" = "1"
    test "${if cfg.my.capabilities.hasNvidiaGpu == (builtins.elem "nvidia" cfg.my.host.gpuVendors) then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-capability-display-topology" = pkgs.runCommand "eval-${name}-capability-display-topology" { } ''
    test "${if cfg.my.capabilities.hasMultipleDisplays == ((builtins.length cfg.my.host.displays) > 1) then "1" else "0"}" = "1"
    test "${if cfg.my.capabilities.hasHiDpiDisplay == (builtins.any (display: let scale = display.scale or null; in if scale == null then false else scale > 1.0) cfg.my.host.displays) then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-home-directory" = pkgs.runCommand "eval-${name}-home-directory" { } ''
    test "${hmCfg.home.homeDirectory}" = "${expectedHome}"
    touch "$out"
  '';

  "eval-${name}-hostname-env" = pkgs.runCommand "eval-${name}-hostname-env" { } ''
    test "${hmCfg.home.sessionVariables.NIX_HOSTNAME or ""}" = "${expectedHostname}"
    touch "$out"
  '';

  "eval-${name}-aria2-rpc-config" = pkgs.runCommand "eval-${name}-aria2-rpc-config" { } ''
    test "${if (hmCfg.programs.aria2.enable or false) then "1" else "0"}" = "1"
    test "${if (hmCfg.programs.aria2.settings."enable-rpc" or false) == aria2EnableRpc then "1" else "0"}" = "1"
    if [ "${if aria2EnableRpc then "1" else "0"}" = "1" ]; then
      test "${toString (hmCfg.programs.aria2.settings."rpc-listen-port" or 0)}" = "6800"
      test "${if (hmCfg.programs.aria2.settings."rpc-listen-all" or false) then "1" else "0"}" = "0"
      test "${if (hmCfg.programs.aria2.settings."rpc-allow-origin-all" or false) then "1" else "0"}" = "1"
    else
      test "${if builtins.hasAttr "rpc-listen-port" hmCfg.programs.aria2.settings then "1" else "0"}" = "0"
      test "${if builtins.hasAttr "rpc-listen-all" hmCfg.programs.aria2.settings then "1" else "0"}" = "0"
      test "${if builtins.hasAttr "rpc-allow-origin-all" hmCfg.programs.aria2.settings then "1" else "0"}" = "0"
    fi
    touch "$out"
  '';

  "eval-${name}-aria2-user-service" = pkgs.runCommand "eval-${name}-aria2-user-service" { } ''
    test "${if hmCfg.systemd.user.services ? aria2 then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-aria2-user-service-scripts-use-store-tools" = pkgs.runCommand "eval-${name}-aria2-user-service-scripts-use-store-tools" { } ''
    prepare_script="${hmCfg.systemd.user.services.aria2.Service.ExecStartPre or ""}"
    start_script="${builtins.elemAt (hmCfg.systemd.user.services.aria2.Service.ExecStart or [ "" ]) 0}"

    test -n "$prepare_script"
    test -f "$prepare_script"
    test -n "$start_script"
    test -f "$start_script"

    grep -F '${pkgs.coreutils}/bin/mkdir' "$prepare_script" >/dev/null
    grep -F '${pkgs.coreutils}/bin/touch' "$prepare_script" >/dev/null
    if [ "${if aria2EnableRpc then "1" else "0"}" = "1" ]; then
      grep -F '${pkgs.coreutils}/bin/cat' "$start_script" >/dev/null
      grep -F 'aria2 RPC is enabled but secret is not readable: ${aria2RpcSecretPath}' "$start_script" >/dev/null
      grep -F 'exit 1' "$start_script" >/dev/null
      grep -F -- '--rpc-secret=$rpc_secret' "$start_script" >/dev/null
    else
      if grep -Fq -- '--rpc-secret' "$start_script"; then
        echo "aria2 RPC is disabled but start script still passes --rpc-secret" >&2
        exit 1
      fi
    fi
    touch "$out"
  '';

  "eval-${name}-user-uid-unset" = pkgs.runCommand "eval-${name}-user-uid-unset" { } ''
    test "${if (cfg.users.users.${mainUser}.uid or null) == null then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-group-gid-unset" = pkgs.runCommand "eval-${name}-group-gid-unset" { } ''
    test "${if (cfg.users.groups.${mainUser}.gid or null) == null then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-accept-flake-config" = pkgs.runCommand "eval-${name}-accept-flake-config" { } ''
    test "${if hasExpectedAcceptFlakeConfig then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-warn-dirty-enabled" = pkgs.runCommand "eval-${name}-warn-dirty-enabled" { } ''
    test "${if (cfg.nix.settings."warn-dirty" or true) then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-passwd-keyring-disabled" = pkgs.runCommand "eval-${name}-passwd-keyring-disabled" { } ''
    test "${if !(cfg.security.pam.services.passwd.enableGnomeKeyring or false) then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-trusted-users" = pkgs.runCommand "eval-${name}-trusted-users" { } ''
    test "${if hasExpectedTrustedUsers then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-trusted-substituters" = pkgs.runCommand "eval-${name}-trusted-substituters" { } ''
    test "${if hasExpectedTrustedSubstituters then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-session-env-no-global-ml-runtime-libs" = pkgs.runCommand "eval-${name}-session-env-no-global-ml-runtime-libs" { } ''
    test "${if !hasGlobalMlRuntimeLibraryPath then "1" else "0"}" = "1"
    test "${if !hasGlobalOpenSslBuildEnv then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-zellij-uses-unstable" = pkgs.runCommand "eval-${name}-zellij-uses-unstable" { } ''
    test "${if hasExpectedZellijPackage then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-mise-upgrade-auto-opt-in" = pkgs.runCommand "eval-${name}-mise-upgrade-auto-opt-in" { } ''
    test "${if hasMiseUpgradeTimer == miseAutoUpgradeEnabled then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-system-zsh-enabled" = pkgs.runCommand "eval-${name}-system-zsh-enabled" { } ''
    test "${if cfg.programs.zsh.enable or false then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-binbash-tmpfiles" = pkgs.runCommand "eval-${name}-binbash-tmpfiles" { } ''
    test "${if hasBinBashTmpfilesLink then "1" else "0"}" = "1"
    test "${if !hasLegacyBinBashActivation then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-secure-boot-gating" = pkgs.runCommand "eval-${name}-secure-boot-gating" { } ''
    test "${if (cfg.boot.lanzaboote.enable or false) == secureBootEnabled then "1" else "0"}" = "1"
    if [ "${if secureBootEnabled then "1" else "0"}" = "0" ]; then
      test "${if cfg.boot.loader.systemd-boot.enable or false then "1" else "0"}" = "1"
    fi
    touch "$out"
  '';

  "eval-${name}-steam-role-gating" = pkgs.runCommand "eval-${name}-steam-role-gating" { } ''
    test "${if (cfg.programs.steam.enable or false) == hasGamingRole then "1" else "0"}" = "1"
    test "${if (cfg.programs.steam.platformOptimizations.enable or false) == hasGamingRole then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-ensure-user-ssh-dir-uses-store-tools" = pkgs.runCommand "eval-${name}-ensure-user-ssh-dir-uses-store-tools" { } ''
    script='${cfg.system.activationScripts.ensureUserSshDir.text or ""}'

    test -n "$script"
    printf '%s\n' "$script" | grep -F '${pkgs.coreutils}/bin/install -d -m 0700 -o ' >/dev/null
    if printf '%s\n' "$script" | grep -qE '(^|[[:space:];|&])install[[:space:]]+-d[[:space:]]+-m[[:space:]]+0700($|[[:space:];|&])'; then
      echo "ensureUserSshDir activation script should not invoke bare 'install'" >&2
      exit 1
    fi
    touch "$out"
  '';

  "eval-${name}-nix-ld-libraries-not-hardcoded-store-paths" = pkgs.runCommand "eval-${name}-nix-ld-libraries-not-hardcoded-store-paths" { } ''
    if [ "${if cfg.programs.nix-ld.enable or false then "1" else "0"}" = "1" ]; then
      test "${if (builtins.length cfg.programs.nix-ld.libraries) > 0 then "1" else "0"}" = "1"
      test "${if builtins.all lib.isDerivation cfg.programs.nix-ld.libraries then "1" else "0"}" = "1"
      # 负向匹配：禁止字面量 string/path 混入 libraries（例如硬编码 /nix/store/...）。
      test "${if builtins.any builtins.isString cfg.programs.nix-ld.libraries then "1" else "0"}" = "0"
      test "${if builtins.any builtins.isPath cfg.programs.nix-ld.libraries then "1" else "0"}" = "0"
    fi
    touch "$out"
  '';

  "eval-${name}-system-home-package-overlap" = mkNonEmptyCheck
    "eval-${name}-system-home-package-overlap"
    unexpectedSystemHomeOverlapNames
    "Unexpected system/home package overlaps";

  "eval-${name}-system-home-package-overlap-by-name" = mkNonEmptyCheck
    "eval-${name}-system-home-package-overlap-by-name"
    unexpectedOverlapByNameFiltered
    "Unexpected system/home package overlaps by name";

  "eval-${name}-system-package-duplicates" = mkNonEmptyCheck
    "eval-${name}-system-package-duplicates"
    unexpectedSystemDuplicateNames
    "Unexpected duplicate packages in environment.systemPackages";

  "eval-${name}-resume-device" = pkgs.runCommand "eval-${name}-resume-device" { } ''
    if [ "${if expectsHibernate then "1" else "0"}" = "1" ]; then
      test "${cfg.boot.resumeDevice or ""}" = "/dev/mapper/${resolvedExpectedLuksName}"
    else
      test "${cfg.boot.resumeDevice or ""}" = ""
    fi
    test "${if hasExpectedResumeDeviceState then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-resume-kernel-param" = pkgs.runCommand "eval-${name}-resume-kernel-param" { } ''
    test "${if hasExpectedResumeKernelParamState then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-resume-offset-kernel-param" = pkgs.runCommand "eval-${name}-resume-offset-kernel-param" { } ''
    test "${if hasExpectedResumeOffsetKernelParamState then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-swapfile-resume-check-service" = pkgs.runCommand "eval-${name}-swapfile-resume-check-service" { } ''
    if [ "${if expectsHibernate then "1" else "0"}" = "1" ]; then
      test "${if swapfileResumeCheckEnabled then "1" else "0"}" = "1"
    else
      test "${if !swapfileResumeCheckEnabled then "1" else "0"}" = "1"
    fi
    touch "$out"
  '';

  "eval-${name}-swap-device" = pkgs.runCommand "eval-${name}-swap-device" { } ''
    test "${cfg.fileSystems."/swap".device}" = "/dev/mapper/${resolvedExpectedLuksName}"
    touch "$out"
  '';
}
// lib.optionalAttrs (resolvedExpectedVideoDrivers != null) {
  "eval-${name}-video-drivers" = pkgs.runCommand "eval-${name}-video-drivers" { } ''
    test "${builtins.toJSON cfg.services.xserver.videoDrivers}" = "${builtins.toJSON resolvedExpectedVideoDrivers}"
    touch "$out"
  '';
}
// lib.optionalAttrs hasVpnRole {
  "eval-${name}-mullvad-vpn-integration" = pkgs.runCommand "eval-${name}-mullvad-vpn-integration" { } ''
    test "${if cfg.services.resolved.enable or false then "1" else "0"}" = "1"
    test "${if cfg.services.mullvad-vpn.enable or false then "1" else "0"}" = "1"
    test "${if (cfg.networking.wg-quick.interfaces or { }) == { } then "1" else "0"}" = "1"
    test "${if cfg.system.activationScripts ? wireguardVpnActiveLinks then "1" else "0"}" = "0"
    test "${if lib.hasInfix "NIXOS_WG_KILLSWITCH" (cfg.networking.firewall.extraCommands or "") then "1" else "0"}" = "0"
    test "${if builtins.elem "vpn-list" systemPackageNames then "1" else "0"}" = "0"
    test "${if builtins.elem "vpn-switch" systemPackageNames then "1" else "0"}" = "0"
    test "${if builtins.elem "vpn-select" systemPackageNames then "1" else "0"}" = "0"
    test "${if builtins.elem "vpn-status" systemPackageNames then "1" else "0"}" = "0"
    test "${if builtins.elem "vpn-stop-all" systemPackageNames then "1" else "0"}" = "0"
    test "${if builtins.elem "wireguard-tools" systemPackageNames then "1" else "0"}" = "1"
    test "${builtins.unsafeDiscardStringContext (lib.getName cfg.services.mullvad-vpn.package)}" = "mullvad-vpn"
    test "${if builtins.elem "mullvad-vpn" systemPackageNames then "1" else "0"}" = "1"
    test "${if builtins.elem "mullvad-vpn" homePackageNames then "1" else "0"}" = "0"
    test "${if builtins.elem "/etc/mullvad-vpn" preservedDirectoryPaths then "1" else "0"}" = "1"
    test "${if builtins.elem "/var/cache/mullvad-vpn" preservedDirectoryPaths then "1" else "0"}" = "1"
    touch "$out"
  '';
}
// {
  "eval-${name}-docker-mode" = pkgs.runCommand "eval-${name}-docker-mode" { } ''
    test "${if hasExpectedDockerMode then "1" else "0"}" = "1"
    touch "$out"
  '';
  "eval-${name}-rootless-docker-linger" = pkgs.runCommand "eval-${name}-rootless-docker-linger" { } ''
    test "${if hasExpectedRootlessDockerLinger then "1" else "0"}" = "1"
    touch "$out"
  '';
}
// lib.optionalAttrs (resolvedExpectedKvmModules != null) {
  "eval-${name}-kvm-modules" = pkgs.runCommand "eval-${name}-kvm-modules" { } ''
    test "${builtins.toJSON actualKvmModules}" = "${builtins.toJSON resolvedExpectedKvmModules}"
    touch "$out"
  '';
}
  // lib.optionalAttrs hasDesktopSession {
  "eval-${name}-greetd-session-command-not-home-bound" = pkgs.runCommand "eval-${name}-greetd-session-command-not-home-bound" { } ''
    if grep -Fq "${expectedHome}/.wayland-session" "${cfg.services.greetd.settings.default_session.command}"; then
      echo "greetd session wrapper still depends on ${expectedHome}/.wayland-session" >&2
      exit 1
    fi
    touch "$out"
  '';

  "eval-${name}-greetd-session-command-imports-gui-vars" = pkgs.runCommand "eval-${name}-greetd-session-command-imports-gui-vars" { } ''
    session_wrapper="$(
      grep -o '/nix/store/[^[:space:]]*-wayland-session' "${cfg.services.greetd.settings.default_session.command}" \
        | head -n1
    )"

    if [ -z "$session_wrapper" ]; then
      echo "failed to locate greetd wayland-session wrapper" >&2
      exit 1
    fi

    for expected_var in \
      NIXOS_OZONE_WL \
      QT_QPA_PLATFORMTHEME \
      NIX_XDG_DESKTOP_PORTAL_DIR \
      XDG_SESSION_TYPE
    do
      if ! grep -Fq "$expected_var" "$session_wrapper"; then
        echo "greetd wayland-session wrapper does not import $expected_var" >&2
        exit 1
      fi
    done

    touch "$out"
  '';

  "eval-${name}-wayland-session-env-sync-autostart" = pkgs.runCommand "eval-${name}-wayland-session-env-sync-autostart" { } ''
    test "${if builtins.elem "wayland-session-env-sync" systemPackageNames then "1" else "0"}" = "1"
    niri_config="${if niriConfigSource == null then "" else niriConfigSource}"
    test -n "$niri_config"
    grep -F 'spawn-at-startup "wayland-session-env-sync"' "$niri_config" >/dev/null
    touch "$out"
  '';

  "eval-${name}-display-manager-session-names" = pkgs.runCommand "eval-${name}-display-manager-session-names" { } ''
    test "${builtins.toJSON cfg.services.displayManager.sessionData.sessionNames}" = "${builtins.toJSON expectedDisplayManagerSessionNames}"
    touch "$out"
  '';

  "eval-${name}-gui-cli-wrappers" = pkgs.runCommand "eval-${name}-gui-cli-wrappers" { } ''
    code_wrapper="${if codeWrapperSource == null then "" else codeWrapperSource}"
    antigravity_wrapper="${if antigravityWrapperSource == null then "" else antigravityWrapperSource}"

    test -n "$code_wrapper"
    test -f "$code_wrapper"
    test -n "$antigravity_wrapper"
    test -f "$antigravity_wrapper"

    grep -F '${lib.getExe pkgs.vscode}' "$code_wrapper" >/dev/null
    for wrapper in "$code_wrapper" "$antigravity_wrapper"; do
      grep -F 'target executable not found or not executable' "$wrapper" >/dev/null
      grep -F 'refusing to execute wrapper recursively' "$wrapper" >/dev/null
      grep -F '${pkgs.coreutils}/bin/readlink' "$wrapper" >/dev/null
      grep -F 'ozone-platform-hint' "$wrapper" >/dev/null
    done

    touch "$out"
  '';
}
