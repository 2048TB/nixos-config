{ mainUser, ... }:
{
  # Darwin 无 sops-nix，SSH key 需手动放置
  programs.ssh.matchBlocks."github.com".identityFile = "/Users/${mainUser}/.ssh/id_ed25519";
}
