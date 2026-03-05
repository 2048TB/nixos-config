_:
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

  system.stateVersion = 6;
}
