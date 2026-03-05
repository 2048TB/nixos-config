# One Dark Pro color palette — single source of truth for the entire desktop theme.
# https://marketplace.visualstudio.com/items?itemName=zhuangtongfa.Material-theme
#
# Nix modules:  mytheme.palette.bg.hex  /  mytheme.palette.bg.rgb
# Config files: @THEME_BG@ (hex without #) / @THEME_BG_RGB@ (r, g, b)
# Apply:        mytheme.apply (builtins.readFile ./template)
{ lib }:
let
  mkColor = hex: rgb: { inherit hex rgb; };

  palette = {
    # UI surfaces
    bg = mkColor "282c34" "40, 44, 52";
    bg1 = mkColor "2c313c" "44, 49, 60";
    bg2 = mkColor "3e4451" "62, 68, 81";
    bg3 = mkColor "5c6370" "92, 99, 112";
    # Foreground
    fg = mkColor "abb2bf" "171, 178, 191";
    fg1 = mkColor "b6bdca" "182, 189, 202";
    fg2 = mkColor "c8ccd4" "200, 204, 212";
    # Accents
    teal = mkColor "56b6c2" "86, 182, 194";
    cyan = mkColor "56b6c2" "86, 182, 194";
    blue = mkColor "61afef" "97, 175, 239";
    deep = mkColor "3e4452" "62, 68, 82";
    # Status colors
    red = mkColor "e06c75" "224, 108, 117";
    orange = mkColor "d19a66" "209, 154, 102";
    yellow = mkColor "e5c07b" "229, 192, 123";
    green = mkColor "98c379" "152, 195, 121";
    purple = mkColor "c678dd" "198, 120, 221";
  };

  # Built-in theme names for apps that ship their own theme catalogs
  apps = {
    ghostty = "Atom One Dark";
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
