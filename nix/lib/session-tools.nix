{ pkgs, ... }:
{
  mkLockScreenPackage =
    { name ? "lock-screen" }:
    pkgs.writeShellScriptBin name ''
      exec ${pkgs.swaylock-effects}/bin/swaylock \
        --clock \
        --indicator \
        --effect-blur 7x5 \
        --fade-in 0.2 \
        -f \
        "$@"
    '';

  mkSwaybgLauncherPackage =
    { name ? "swaybg-launcher" }:
    pkgs.writeShellScriptBin name ''
      wallpaperDir="$HOME/.config/wallpapers"
      wallpaper="$wallpaperDir/1.png"
      if [ ! -f "$wallpaper" ]; then
        echo "swaybg-launcher: wallpaper not found: $wallpaper" >&2
        exit 1
      fi
      exec ${pkgs.swaybg}/bin/swaybg -i "$wallpaper" -m fill
    '';
}
