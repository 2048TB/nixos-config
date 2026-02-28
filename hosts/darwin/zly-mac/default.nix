{ mainUser, ... }:
let
  hostname = "zly-mac";
in
{
  networking.hostName = hostname;
  networking.computerName = hostname;
  system.defaults.smb.NetBIOSName = hostname;

  # Ghostty is installed via Homebrew on macOS because nixpkgs-darwin
  # does not currently provide a package for this host platform.
  homebrew = {
    casks = [ "ghostty" ];
  };

  home-manager.users.${mainUser}.programs.ssh.matchBlocks."github.com".identityFile =
    "/Users/${mainUser}/.ssh/zly-mac";

  system.stateVersion = 6;
}
