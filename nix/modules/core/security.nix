{ pkgs
, myvars
, ...
}:
let
  enableAggressiveApparmorKill = myvars.enableAggressiveApparmorKill or false;
in
{
  security = {
    apparmor = {
      enable = true;
      killUnconfinedConfinables = enableAggressiveApparmorKill;
      packages = with pkgs; [
        apparmor-utils
        apparmor-profiles
      ];
    };

    polkit = {
      enable = true;
      # 恢复单用户桌面体验：wheel 组对 UDisks 挂载类操作直接放行。
      extraConfig = ''
        polkit.addRule(function(action, subject) {
          var guardedActions = [
            "org.freedesktop.udisks2.filesystem-mount",
            "org.freedesktop.udisks2.filesystem-mount-system",
            "org.freedesktop.udisks2.filesystem-mount-other-seat",
            "org.freedesktop.udisks2.filesystem-unmount-others",
            "org.freedesktop.udisks2.encrypted-unlock",
            "org.freedesktop.udisks2.encrypted-lock-others",
            "org.freedesktop.udisks2.loop-setup",
            "org.freedesktop.udisks2.power-off-drive"
          ];
          if (subject.isInGroup("wheel") && guardedActions.indexOf(action.id) >= 0) {
            return polkit.Result.YES;
          }
        });
      '';
    };
    rtkit.enable = true;
    pam.services.greetd.enableGnomeKeyring = true;
    pam.services.passwd.enableGnomeKeyring = true;
  };
}
