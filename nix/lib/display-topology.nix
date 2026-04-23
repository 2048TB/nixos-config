{ lib }:
let
  getDisplays = host: host.displays or [ ];

  primaryDisplay =
    host:
    let
      displays = getDisplays host;
      explicitPrimary = builtins.filter (display: display.primary or false) displays;
    in
    if explicitPrimary != [ ] then builtins.head explicitPrimary
    else if displays != [ ] then builtins.head displays
    else null;

  outputIdentifier =
    display:
    let
      match = display.match or null;
      name = display.name or null;
    in
    if match != null && match != "" then match
    else if name != null && name != "" then name
    else null;

  renderMode =
    display:
    let
      width = display.width or null;
      height = display.height or null;
      refresh = display.refresh or null;
    in
    if width == null || height == null then null
    else if refresh == null then "${toString width}x${toString height}"
    else "${toString width}x${toString height}@${toString refresh}";

  renderWlrRandrMode =
    display:
    let
      width = display.width or null;
      height = display.height or null;
      refresh = display.refresh or null;
    in
    if width == null || height == null then null
    else if refresh == null then "${toString width}x${toString height}"
    else "${toString width}x${toString height}@${toString refresh}Hz";

in
{
  inherit primaryDisplay;

  mkRiverOutputSetupScript =
    host:
    let
      displays =
        builtins.filter
          (display: (display.name or "") != "")
          (getDisplays host);
      mkCommand =
        display:
        let
          mode = renderWlrRandrMode display;
          scale = display.scale or null;
          modeArg =
            if mode == null then "" else " --mode ${lib.escapeShellArg mode}";
          scaleArg =
            if scale == null then "" else " --scale ${lib.escapeShellArg (toString scale)}";
        in
        "apply_output ${lib.escapeShellArg display.name} --on${modeArg}${scaleArg}";
    in
    ''
      #!/bin/sh
      set -eu

      if ! command -v wlr-randr >/dev/null 2>&1; then
        exit 0
      fi

      current_outputs="$(wlr-randr || true)"

      apply_output() {
        output="$1"
        shift
        if printf '%s\n' "$current_outputs" | grep -Fq "$output"; then
          wlr-randr --output "$output" "$@" >/dev/null 2>&1 || true
        fi
      }

      ${lib.concatStringsSep "\n" (map mkCommand displays)}
    '';
}
