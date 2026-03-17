{ lib }:
let
  mkAction =
    { label
    , action
    , text
    , keybind
    }:
    builtins.toJSON {
      inherit label action text keybind;
    };
in
{
  mkWlogoutLayout =
    { supportsHibernate ? true }:
    lib.concatStringsSep "\n" (
      [
        (mkAction {
          label = "lock";
          action = "/etc/profiles/per-user/$USER/bin/lock-screen";
          text = "Lock";
          keybind = "l";
        })
        (mkAction {
          label = "logout";
          action = "loginctl terminate-session \"$XDG_SESSION_ID\"";
          text = "Logout";
          keybind = "e";
        })
        (mkAction {
          label = "suspend";
          action = "systemctl suspend";
          text = "Suspend";
          keybind = "u";
        })
      ]
      ++ lib.optional supportsHibernate (mkAction {
        label = "hibernate";
        action = "systemctl hibernate";
        text = "Hibernate";
        keybind = "h";
      })
      ++ [
        (mkAction {
          label = "reboot";
          action = "systemctl reboot";
          text = "Reboot";
          keybind = "r";
        })
        (mkAction {
          label = "shutdown";
          action = "systemctl poweroff";
          text = "Shutdown";
          keybind = "s";
        })
      ]
    );
}
