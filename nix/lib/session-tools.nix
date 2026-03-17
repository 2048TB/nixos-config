{ pkgs, mytheme }:
{
  mkLockScreenPackage =
    { name ? "lock-screen" }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = with pkgs; [
        coreutils
        swaylock-effects
      ];
      text = mytheme.apply (builtins.readFile ../scripts/session/lock-screen.sh);
    };

  mkWlogoutMenuPackage =
    { name ? "wlogout-menu" }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = with pkgs; [ wlogout ];
      text = builtins.readFile ../scripts/session/wlogout-menu.sh;
    };

  mkSwaybgLauncherPackage =
    { name ? "swaybg-launcher" }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = with pkgs; [ coreutils findutils swaybg ];
      text = builtins.readFile ../scripts/session/swaybg-launcher.sh;
    };
}
