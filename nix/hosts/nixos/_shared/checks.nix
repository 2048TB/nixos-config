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
  hasDesktopSession = cfg.my.capabilities.hasDesktopSession or false;
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
  hasProvider appVpn = cfg.services.provider-app-vpn.enable or false;
  provider-appDispatcherScripts = cfg.networking.networkmanager.dispatcherScripts or [ ];
  provider-appDispatcherPaths = map (script: toString (script.source or "")) provider-appDispatcherScripts;
  provider-appRecoveryScript = cfg.systemd.services.provider-app-recover.script or "";
  provider-appKillSwitchCommands = cfg.networking.firewall.extraCommands or "";
  provider-appKillSwitchStopCommands = cfg.networking.firewall.extraStopCommands or "";
  hmCfg = cfg.home-manager.users.${mainUser};
  expectedHome = "/home/${mainUser}";

  getNames = pkgList: lib.unique (map lib.getName pkgList);
  excludeAllowed = allowed: names: builtins.filter (n: !(builtins.elem n allowed)) names;

  allSystemPackageOutPaths = map (pkg: pkg.outPath) cfg.environment.systemPackages;
  systemPackageOutPaths = lib.unique allSystemPackageOutPaths;
  homePackageOutPaths = lib.unique (map (pkg: pkg.outPath) hmCfg.home.packages);
  systemHomeOverlapOutPaths = lib.intersectLists systemPackageOutPaths homePackageOutPaths;
  systemHomeOverlapPkgs =
    lib.filter (pkg: builtins.elem pkg.outPath systemHomeOverlapOutPaths) cfg.environment.systemPackages;
  systemHomeOverlapNames = getNames systemHomeOverlapPkgs;
  systemPackageNames = getNames cfg.environment.systemPackages;
  homePackageNames = getNames hmCfg.home.packages;
  unexpectedOverlapByName = lib.intersectLists systemPackageNames homePackageNames;
  systemDuplicateOutPaths =
    lib.unique (
      builtins.filter
        (outPath: (builtins.length (builtins.filter (p: p == outPath) allSystemPackageOutPaths)) > 1)
        allSystemPackageOutPaths
    );
  systemDuplicatePkgs =
    lib.filter
      (pkg: builtins.elem pkg.outPath systemDuplicateOutPaths)
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
    test "${if (hmCfg.programs.aria2.settings."enable-rpc" or false) then "1" else "0"}" = "1"
    test "${toString (hmCfg.programs.aria2.settings."rpc-listen-port" or 0)}" = "6800"
    test "${if (hmCfg.programs.aria2.settings."rpc-listen-all" or false) then "1" else "0"}" = "0"
    test "${if (hmCfg.programs.aria2.settings."rpc-allow-origin-all" or false) then "1" else "0"}" = "1"
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
    grep -F '${pkgs.coreutils}/bin/cat' "$start_script" >/dev/null
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

  "eval-${name}-binbash-script-uses-store-tools" = pkgs.runCommand "eval-${name}-binbash-script-uses-store-tools" { } ''
    script='${cfg.system.activationScripts.binbash.text or ""}'

    test -n "$script"
    printf '%s\n' "$script" | grep -F '${pkgs.coreutils}/bin/mkdir -p /bin' >/dev/null
    printf '%s\n' "$script" | grep -F '${pkgs.coreutils}/bin/ln -sfn /run/current-system/sw/bin/bash /bin/bash' >/dev/null

    # 负向匹配：禁止回退为 PATH 依赖的裸命令调用。
    if printf '%s\n' "$script" | grep -qE '(^|[[:space:];|&])mkdir[[:space:]]+-p[[:space:]]+/bin($|[[:space:];|&])'; then
      echo "binbash activation script should not invoke bare 'mkdir'" >&2
      exit 1
    fi
    if printf '%s\n' "$script" | grep -qE '(^|[[:space:];|&])ln[[:space:]]+-sfn[[:space:]]+/run/current-system/sw/bin/bash[[:space:]]+/bin/bash($|[[:space:];|&])'; then
      echo "binbash activation script should not invoke bare 'ln'" >&2
      exit 1
    fi
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
// lib.optionalAttrs hasProvider appVpn {
  "eval-${name}-provider-app-no-nm-dispatcher" = pkgs.runCommand "eval-${name}-provider-app-no-nm-dispatcher" { } ''
    test '${builtins.toJSON provider-appDispatcherPaths}' = '[]'
    touch "$out"
  '';

  "eval-${name}-provider-app-recovery-systemd-units" = pkgs.runCommand "eval-${name}-provider-app-recovery-systemd-units" { } ''
    test "${if cfg.systemd.services ? provider-app-recover then "1" else "0"}" = "1"
    test "${if cfg.systemd.timers ? provider-app-recover then "1" else "0"}" = "1"
    test "${toString (cfg.systemd.services.provider-app-recover.serviceConfig.StateDirectory or "")}" = "provider-app-recover"
    test "${toString (cfg.systemd.services.provider-app-recover.serviceConfig.RuntimeDirectory or "")}" = "provider-app-recover"
    touch "$out"
  '';

  "eval-${name}-provider-app-recovery-script" = pkgs.runCommand "eval-${name}-provider-app-recovery-script" { } ''
    script=${pkgs.writeText "eval-${name}-provider-app-recovery-script" provider-appRecoveryScript}

    grep -F '${pkgs.util-linux}/bin/flock' "$script" >/dev/null
    grep -F '${pkgs.systemd}/bin/systemctl restart provider-app-daemon.service' "$script" >/dev/null
    grep -F '${pkgs.provider-app}/bin/provider-app connect' "$script" >/dev/null
    grep -F 'action_cooldown=900' "$script" >/dev/null
    grep -F 'min_trouble_age=600' "$script" >/dev/null
    grep -F 'classify_status_line()' "$script" >/dev/null
    grep -F 'status_line="$(printf' "$script" >/dev/null
    grep -F 'status_class="$(classify_status_line "$status_line")"' "$script" >/dev/null
    grep -F 'post_restart_status_class="$(classify_status_line "$post_restart_status_line")"' "$script" >/dev/null
    grep -F 'provider-app-recover' "$script" >/dev/null
    if grep -F '*Connected*' "$script" >/dev/null; then
      echo "recovery script must not use broad *Connected* status matching" >&2
      exit 1
    fi
    if grep -F '*Connecting*' "$script" >/dev/null; then
      echo "recovery script must not use broad *Connecting* status matching" >&2
      exit 1
    fi
    touch "$out"
  '';

  "eval-${name}-provider-app-killswitch-firewall" = pkgs.runCommand "eval-${name}-provider-app-killswitch-firewall" { } ''
    commands=${pkgs.writeText "eval-${name}-provider-app-killswitch-commands" provider-appKillSwitchCommands}
    stop_commands=${pkgs.writeText "eval-${name}-provider-app-killswitch-stop-commands" provider-appKillSwitchStopCommands}

    grep -F 'nixos-provider-app-killswitch' "$commands" >/dev/null
    grep -F -- '-o wg-provider-app -j RETURN' "$commands" >/dev/null
    grep -F -- '-o tun0 -j RETURN' "$commands" >/dev/null
    grep -F -- '--uid-owner 0 -p udp -m multiport --dports 53,123,51820' "$commands" >/dev/null
    grep -F -- '--uid-owner 0 -p tcp --dport 443' "$commands" >/dev/null
    grep -F 'provider-app killswitch drop: ' "$commands" >/dev/null
    grep -F -- '-j REJECT' "$commands" >/dev/null
    grep -F 'nixos-provider-app-killswitch' "$stop_commands" >/dev/null
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
      NIX_XDG_DESKTOP_PORTAL_DIR
    do
      if ! grep -Fq "$expected_var" "$session_wrapper"; then
        echo "greetd wayland-session wrapper does not import $expected_var" >&2
        exit 1
      fi
    done

    touch "$out"
  '';
}
