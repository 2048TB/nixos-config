{ pkgs
, lib
, mainUser
, ...
}:
{
  system.primaryUser = mainUser;

  programs.zsh.enable = true;
  users.users.${mainUser}.shell = lib.mkDefault pkgs.zsh;
  environment.shells = lib.mkDefault [ pkgs.zsh ];

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "none";
    };
  };
}
