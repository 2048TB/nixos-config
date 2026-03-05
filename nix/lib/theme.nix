# Nord color palette — single source of truth for the entire desktop theme.
# https://www.nordtheme.com/docs/colors-and-palettes
#
# Nix modules:  mytheme.palette.bg.hex  /  mytheme.palette.bg.rgb
# Config files: @THEME_BG@ (hex without #) / @THEME_BG_RGB@ (r, g, b)
# Apply:        mytheme.apply (builtins.readFile ./template)
{ lib }:
let
  mkColor = hex: rgb: { inherit hex rgb; };

  palette = {
    # Polar Night
    bg = mkColor "2e3440" "46, 52, 64";
    bg1 = mkColor "3b4252" "59, 66, 82";
    bg2 = mkColor "434c5e" "67, 76, 94";
    bg3 = mkColor "4c566a" "76, 86, 106";
    # Snow Storm
    fg = mkColor "d8dee9" "216, 222, 233";
    fg1 = mkColor "e5e9f0" "229, 233, 240";
    fg2 = mkColor "eceff4" "236, 239, 244";
    # Frost
    teal = mkColor "8fbcbb" "143, 188, 187";
    cyan = mkColor "88c0d0" "136, 192, 208";
    blue = mkColor "81a1c1" "129, 161, 193";
    deep = mkColor "5e81ac" "94, 129, 172";
    # Aurora
    red = mkColor "bf616a" "191, 97, 106";
    orange = mkColor "d08770" "208, 135, 112";
    yellow = mkColor "ebcb8b" "235, 203, 139";
    green = mkColor "a3be8c" "163, 190, 140";
    purple = mkColor "b48ead" "180, 142, 173";
  };

  # Built-in theme names for apps that ship their own theme catalogs
  apps = {
    ghostty = "Nord";
  };

  mkSubst = name: color:
    let upper = lib.toUpper name;
    in {
      names = [ "@THEME_${upper}@" "@THEME_${upper}_RGB@" ];
      values = [ color.hex color.rgb ];
    };

  colorSubsts = lib.mapAttrsToList mkSubst palette;
  allNames = builtins.concatMap (s: s.names) colorSubsts ++ [ "@THEME_GHOSTTY@" ];
  allValues = builtins.concatMap (s: s.values) colorSubsts ++ [ apps.ghostty ];
in
{
  inherit palette apps;
  apply = str: builtins.replaceStrings allNames allValues str;
}
