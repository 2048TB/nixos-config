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
  provider-appDispatcherPath =
    if provider-appDispatcherScripts == [ ] then ""
    else toString (builtins.head provider-appDispatcherScripts).source or "";
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
  allowedSystemDuplicateNames = [
    "dosfstools"
    "fuse"
    "gnome-keyring"
    "niri"
    "iptables"
    "less"
    "shadow"
    "zsh"
  ];
  unexpectedSystemDuplicateNames = excludeAllowed allowedSystemDuplicateNames systemDuplicateNames;
  allowedSystemHomeOverlapNames = [
    "xwayland"
    "xdg-desktop-portal"
    "xdg-desktop-portal-gnome"
    "xdg-desktop-portal-gtk"
    "python3"
    "zsh"
    "nix-zsh-completions"
    "man-db"
    "shared-mime-info"
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
    source_module='${builtins.readFile ../../../modules/core/default.nix}'
    binbash_block="$(
      printf '%s\n' "$source_module" \
        | sed -n '/binbash[[:space:]]*=[[:space:]]*{/,/^[[:space:]]*};[[:space:]]*$/p'
    )"

    test -n "$binbash_block"
    printf '%s\n' "$binbash_block" | grep -F '/bin/mkdir -p /bin' >/dev/null
    printf '%s\n' "$binbash_block" | grep -F '/bin/ln -sfn /run/current-system/sw/bin/bash /bin/bash' >/dev/null
    touch "$out"
  '';

  "eval-${name}-ensure-user-ssh-dir-uses-store-tools" = pkgs.runCommand "eval-${name}-ensure-user-ssh-dir-uses-store-tools" { } ''
    source_module='${builtins.readFile ../../../modules/core/secrets.nix}'
    ensure_ssh_dir_block="$(
      printf '%s\n' "$source_module" \
        | sed -n '/ensureUserSshDir[[:space:]]*=[[:space:]]*{/,/^[[:space:]]*};[[:space:]]*$/p'
    )"

    test -n "$ensure_ssh_dir_block"
    printf '%s\n' "$ensure_ssh_dir_block" | grep -F '/bin/install -d -m 0700 -o ' >/dev/null
    touch "$out"
  '';

  "eval-${name}-nix-ld-libraries-not-hardcoded-store-paths" = pkgs.runCommand "eval-${name}-nix-ld-libraries-not-hardcoded-store-paths" { } ''
    if [ "${if cfg.programs.nix-ld.enable or false then "1" else "0"}" = "1" ]; then
      desktop_module='${builtins.readFile ../../../modules/core/desktop.nix}'
      nix_ld_block="$(
        printf '%s\n' "$desktop_module" \
          | sed -n '/nix-ld[[:space:]]*=[[:space:]]*{/,/^[[:space:]]*};[[:space:]]*$/p'
      )"

      test -n "$nix_ld_block"
      if printf '%s\n' "$nix_ld_block" | grep -q '/nix/store/'; then
        echo "programs.nix-ld.libraries should not hardcode /nix/store paths" >&2
        exit 1
      fi
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
  # 验证 NM dispatcher 使用 `provider-app connect`（而非 reconnect，后者在 Disconnected 状态下静默无操作）
  "eval-${name}-provider-app-dispatcher-uses-connect" = pkgs.runCommand "eval-${name}-provider-app-dispatcher-uses-connect" { } ''
    script_path="${provider-appDispatcherPath}"
    non_comment_script="$(grep -v '^[[:space:]]*#' "$script_path")"

    if [ -z "$script_path" ] || [ ! -f "$script_path" ]; then
      echo "missing provider-app NM dispatcher script" >&2
      exit 1
    fi

    # 必须使用 connect 而非 reconnect（上游 #6220：reconnect 在断连状态下不生效）
    # 只检测非注释行中的实际命令调用
    if ! printf '%s\n' "$non_comment_script" | grep -qE '(^|[^[:alnum:]_])connect([^[:alnum:]_]|$)'; then
      echo "dispatcher should use 'provider-app connect'" >&2
      exit 1
    fi
    if printf '%s\n' "$non_comment_script" | grep -qE '(^|[^[:alnum:]_])reconnect([^[:alnum:]_]|$)'; then
      echo "dispatcher should use 'provider-app connect', not 'provider-app reconnect'" >&2
      exit 1
    fi
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
