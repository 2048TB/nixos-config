let
  common = {
    default = [ "gnome" "gtk" ];
    "org.freedesktop.impl.portal.Settings" = [ "gtk" ];
    "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
  };
in
{
  inherit common;

  river = common // {
    "org.freedesktop.impl.portal.Inhibit" = [ "gtk" ];
    "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
    "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
  };
}
