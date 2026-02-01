{ preservation, mainUser, ... }:
{
  imports = [ preservation.nixosModules.default ];

  preservation.enable = true;
  # preservation 需要 initrd systemd
  boot.initrd.systemd.enable = true;

  preservation.preserveAt."/persistent" = {
    directories = [
      "/etc/NetworkManager/system-connections"
      "/etc/ssh"
      "/etc/nix"
      "/etc/secureboot"

      "/var/log"
      "/var/lib/nixos"
      "/var/lib/systemd"
      "/var/lib/NetworkManager"
      "/var/lib/bluetooth"
    ];
    files = [
      {
        file = "/etc/machine-id";
        inInitrd = true;
      }
    ];

    users.${mainUser} = {
      directories = [
        "Downloads"
        "Documents"
        "Pictures"
        "Videos"
        "Music"
        "nixos-config"
        ".config"
        ".local/share"
        ".local/state"
        ".cache"
      ];
    };
  };
}
