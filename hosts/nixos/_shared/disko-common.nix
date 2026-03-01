{ myvars, ... }:
{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = myvars.diskDevice;
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              label = "ESP";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "fmask=0077" "dmask=0077" ];
              };
            };
            NIXOS_CRYPT = {
              size = "100%";
              label = "NIXOS-CRYPT";
              content = {
                type = "luks";
                name = "crypted-nixos";
                settings = {
                  allowDiscards = true;
                };
                extraFormatArgs = [ "--type" "luks2" "--pbkdf" "argon2id" ];
                extraOpenArgs = [ "--allow-discards" "--perf-no_read_workqueue" "--perf-no_write_workqueue" ];
                content = {
                  type = "btrfs";
                  extraArgs = [ "-L" "crypted-nixos" ];
                  subvolumes = {
                    "@root" = { };
                    "@nix" = {
                      mountpoint = "/nix";
                      mountOptions = [ "noatime" "compress-force=zstd:1" ];
                    };
                    "@persistent" = {
                      mountpoint = "/persistent";
                      mountOptions = [ "compress-force=zstd:1" ];
                    };
                    "@home" = {
                      mountpoint = "/home";
                      mountOptions = [ "compress=zstd" "noatime" ];
                    };
                    "@snapshots" = { };
                    "@tmp" = { };
                    "@swap" = {
                      mountpoint = "/swap";
                      mountOptions = [ "noatime" "nodatacow" "compress=no" ];
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
