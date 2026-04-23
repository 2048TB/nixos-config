{ lib
, runCommand
, kwm-river
,
}:

runCommand "river-kwm-session"
{
  passthru.providedSessions = [ "river" ];
  meta = {
    description = "River session wrapper using kwm";
    mainProgram = "river-kwm-session";
    platforms = lib.platforms.linux;
  };
}
  ''
    mkdir -p "$out/bin" "$out/share/wayland-sessions"

    exec_line="$(sed -n 's/^[[:space:]]*Exec=//p' ${kwm-river}/share/wayland-sessions/river-kwm.desktop | head -n1)"

    cat > "$out/bin/river-kwm-session" <<'EOF'
    #!/bin/sh
    exec __KWM_RIVER_EXEC__
    EOF
    substituteInPlace "$out/bin/river-kwm-session" --replace-fail "__KWM_RIVER_EXEC__" "$exec_line"
    chmod +x "$out/bin/river-kwm-session"

    cat > "$out/share/wayland-sessions/river.desktop" <<EOF
    [Desktop Entry]
    Name=River
    Comment=River Wayland compositor with kwm
    Exec=$out/bin/river-kwm-session
    Type=Application
    DesktopNames=river
    EOF
  ''
