{ config
, pkgs
, lib
, mylib
, ...
}:
let
  hostCfg = config.my.host;
  roleFlags = mylib.roleFlags hostCfg;
  inherit (roleFlags) enableMullvadVpn enableLibvirtd enableDocker;
  enableFlatpak = config.my.profiles.desktop;
  hibernateEnabled = hostCfg.resumeOffset != null;
  useRootfulDocker = hostCfg.dockerMode == "rootful";
  luksMapperDevice = "/dev/mapper/${hostCfg.luksName}";
in
{
  preservation.enable = true;
  preservation.preserveAt = {
    "/persistent" = {
      directories = [
        "/root"
        "/etc/NetworkManager/system-connections"
        "/etc/ssh"
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
  };

  # /etc/machine-id 已持久化到 /persistent；systemd-machine-id-commit 仅适用于临时 machine-id。
  # 保留该服务会在 switch 阶段误报失败并导致 nixos-rebuild 返回非零。
  systemd.services.systemd-machine-id-commit.enable = lib.mkForce false;

  fileSystems = {
    "/" = lib.mkForce {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [
        "relatime"
        "mode=755"
        "size=2G"
      ];
    };

    "/swap" = lib.mkForce {
      device =
        if config.fileSystems ? "/nix" && config.fileSystems."/nix" ? device
        then config.fileSystems."/nix".device
        else luksMapperDevice;
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

  swapDevices = [{ device = "/swap/swapfile"; }];

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

    warnSwapfileSizeMismatch = {
      text = ''
        if [ "${if hibernateEnabled then "1" else "0"}" = "1" ] && [ -f /swap/swapfile ]; then
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
          if [ "${if hibernateEnabled then "1" else "0"}" = "1" ] && [ -f /swap/swapfile ] && [ -n "$configured_resume_offset" ]; then
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
  };
}
