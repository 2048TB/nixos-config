{ config
, pkgs
, lib
, mylib
, mainUser
, ...
}:
let
  hostCfg = config.my.host;
  homeDir = "/home/${mainUser}";
  inherit (hostCfg) configRepoPath;
  roleFlags = mylib.roleFlags hostCfg;
  inherit (roleFlags) enableMullvadVpn enableLibvirtd enableDocker enableFlatpak useRootfulDocker;
  inherit (hostCfg) rootTmpfsSize enableHibernate;

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
in
{
  preservation.enable = true;
  preservation.preserveAt."/persistent" = {
    directories = [
      "/root"
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
      "/var/lib/libvirt"
    ]
    ++ lib.optionals (enableDocker && useRootfulDocker) [
      "/var/lib/docker"
    ]
    ++ lib.optionals enableMullvadVpn [
      "/etc/mullvad-vpn"
      "/var/cache/mullvad-vpn"
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

    "/persistent" = {
      neededForBoot = lib.mkDefault true;
    };

    "/home" = {
      neededForBoot = lib.mkDefault true;
    };
  };

  swapDevices = [
    { device = "/swap/swapfile"; }
  ];

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    priority = 100;
    memoryPercent = 50;
  };

  system.activationScripts = {
    createSwapfileIfMissing = {
      text = ''
        if [ -d /swap ] && [ ! -f /swap/swapfile ]; then
          ${pkgs.btrfs-progs}/bin/btrfs filesystem mkswapfile \
            --size ${toString hostCfg.swapSizeGb}g \
            --uuid clear \
            /swap/swapfile
          chmod 600 /swap/swapfile
        fi
      '';
      deps = [ "specialfs" ];
    };

    warnMissingResumeOffset = {
      text = ''
        if [ "${if enableHibernate then "1" else "0"}" = "1" ] && [ -f /swap/swapfile ] && [ -z "${if hostCfg.resumeOffset != null then toString hostCfg.resumeOffset else ""}" ]; then
          echo "WARNING: my.host.resumeOffset is not set on host ${hostCfg.hostname}." >&2
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
          target_size_bytes=$(( ${toString hostCfg.swapSizeGb} * 1024 * 1024 * 1024 ))
          if [ "$current_size_bytes" -ne "$target_size_bytes" ]; then
            echo "WARNING: /swap/swapfile size ($current_size_bytes bytes) != configured ${toString hostCfg.swapSizeGb}GiB ($target_size_bytes bytes) on host ${hostCfg.hostname}." >&2
            echo "WARNING: recreate swapfile and refresh my.host.resumeOffset before relying on hibernate." >&2
          fi
        fi
      '';
      deps = [ "specialfs" ];
    };

    warnResumeOffsetMismatch = {
      text = ''
          configured_resume_offset="${if hostCfg.resumeOffset != null then toString hostCfg.resumeOffset else ""}"
          if [ "${if enableHibernate then "1" else "0"}" = "1" ] && [ -f /swap/swapfile ] && [ -n "$configured_resume_offset" ]; then
            btrfs_bin="${pkgs.btrfs-progs}/bin/btrfs"
            head_bin="${pkgs.coreutils}/bin/head"
            actual_resume_offset="$("$btrfs_bin" inspect-internal map-swapfile -r /swap/swapfile 2>/dev/null | "$head_bin" -n 1 || true)"
            case "$actual_resume_offset" in
              ""|*[!0-9]*)
                ;;
              *)
                if [ "$actual_resume_offset" != "$configured_resume_offset" ]; then
                  echo "WARNING: my.host.resumeOffset ($configured_resume_offset) != actual swapfile resume offset ($actual_resume_offset) on host ${hostCfg.hostname}." >&2
                  echo "WARNING: update hosts/nixos/${hostCfg.hostname}/vars.nix: resumeOffset = $actual_resume_offset;" >&2
                fi
                ;;
            esac
        fi
      '';
      deps = [ "specialfs" ];
    };

    fixUserHomePerms = mkFixOwnershipScript homeDir;
    fixPersistentConfigRepoPerms = mkFixOwnershipScript configRepoPath;
  };
}
