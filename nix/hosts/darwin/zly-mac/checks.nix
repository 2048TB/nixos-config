{ lib
, pkgs
, name
, mainUser
, darwinSystem
, ...
}:
let
  cfg = darwinSystem.config;
  hmCfg = cfg.home-manager.users.${mainUser};
  expectedHome = "/Users/${mainUser}";
  sshConfigActivationData = hmCfg.home.activation.installSshConfig.data or "";
in
{
  "eval-${name}-hostname" = pkgs.runCommand "eval-${name}-hostname" { } ''
    test "${cfg.networking.hostName}" = "${name}"
    touch "$out"
  '';

  "eval-${name}-home-directory" = pkgs.runCommand "eval-${name}-home-directory" { } ''
    test "${hmCfg.home.homeDirectory}" = "${expectedHome}"
    touch "$out"
  '';

  "eval-${name}-user-shell-zsh" = pkgs.runCommand "eval-${name}-user-shell-zsh" { } ''
    test "${if cfg.users.users.${mainUser}.shell == pkgs.zsh then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-hm-zsh-enabled" = pkgs.runCommand "eval-${name}-hm-zsh-enabled" { } ''
    test "${if hmCfg.programs.zsh.enable then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-hm-shell-env" = pkgs.runCommand "eval-${name}-hm-shell-env" { } ''
    test "${if hmCfg.home.sessionVariables ? BUN_INSTALL then "1" else "0"}" = "1"
    test "${if hmCfg.home.sessionVariables ? GOPATH then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-ssh-config-runtime" = pkgs.runCommand "eval-${name}-ssh-config-runtime" { } ''
    test "${if (hmCfg.programs.ssh.enable or false) then "1" else "0"}" = "0"
    test "${if hmCfg.home.activation ? installSshConfig then "1" else "0"}" = "1"
    test "${if lib.hasInfix "${expectedHome}/.ssh/id_ed25519" sshConfigActivationData then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-ghostty-cask" = pkgs.runCommand "eval-${name}-ghostty-cask" { } ''
    test "${if builtins.elem "ghostty" cfg.homebrew.casks then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-homebrew-enabled" = pkgs.runCommand "eval-${name}-homebrew-enabled" { } ''
    test "${if cfg.homebrew.enable then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-nix-homebrew-enabled" = pkgs.runCommand "eval-${name}-nix-homebrew-enabled" { } ''
    test "${if cfg.nix-homebrew.enable then "1" else "0"}" = "1"
    touch "$out"
  '';

  "eval-${name}-nix-homebrew-user" = pkgs.runCommand "eval-${name}-nix-homebrew-user" { } ''
    test "${cfg.nix-homebrew.user}" = "${mainUser}"
    touch "$out"
  '';
}
