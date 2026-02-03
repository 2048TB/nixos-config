{ config
, pkgs
, ...
}:
{
  services.dbus.apparmor = "enabled";
  security.apparmor = {
    enable = true;

    # kill process that are not confined but have apparmor profiles enabled
    killUnconfinedConfinables = true;
    packages = with pkgs; [
      apparmor-utils
      apparmor-profiles
    ];

    # apparmor policies (disabled for now - can be re-enabled later)
    # policies = {
    #   "default_deny".profile = ''
    #     profile default_deny /** { }
    #   '';
    #   "sudo".profile = ''
    #     ${pkgs.sudo}/bin/sudo {
    #       file /** rwlkUx,
    #     }
    #   '';
    #   "nix".profile = ''
    #     ${config.nix.package}/bin/nix {
    #       unconfined,
    #     }
    #   '';
    # };
  };

}
