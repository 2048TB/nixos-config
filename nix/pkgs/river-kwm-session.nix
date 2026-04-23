{ lib
, runCommand
, river-classic
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

    cat > "$out/bin/river-kwm-session" <<'EOF'
    #!/bin/sh
    exec ${lib.getExe river-classic} -c ${lib.getExe kwm-river}
    EOF
    chmod +x "$out/bin/river-kwm-session"

    cat > "$out/share/wayland-sessions/river.desktop" <<'EOF'
    [Desktop Entry]
    Name=River
    Comment=River Wayland compositor with kwm
    Exec=$out/bin/river-kwm-session
    Type=Application
    DesktopNames=river
    EOF
  ''
