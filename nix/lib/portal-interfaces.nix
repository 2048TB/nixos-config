_:
let
  gtkInterfaces = {
    "org.freedesktop.impl.portal.Settings" = [ "gtk" ];
    "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
  };
in
{
  defaultBackends = [ "gtk" ];
  inherit gtkInterfaces;
  hyprlandInterfaces = gtkInterfaces // {
    default = [ "hyprland" "gtk" ];
    # Hyprland backend does not implement Inhibit; route to gtk.
    "org.freedesktop.impl.portal.Inhibit" = [ "gtk" ];
  };
}
