{ mainUser, ... }:
{
  home.sessionVariables.HOST_PROFILE = "zly-mac";

  # 主机级 SSH key 选择
  programs.ssh.matchBlocks."github.com".identityFile = "/Users/${mainUser}/.ssh/zly-mac";
}
