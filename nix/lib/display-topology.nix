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

  mkNiriOutputBlock =
    display:
    let
      identifier = outputIdentifier display;
      mode = renderMode display;
      scale = display.scale or null;
      lines =
        lib.filter (line: line != null) [
          (if identifier == null then null else "output \"${identifier}\" {")
          (if mode == null then null else "    mode \"${mode}\"")
          (if scale == null then null else "    scale ${toString scale}")
          (if identifier == null then null else "}")
        ];
    in
    if identifier == null then "" else lib.concatStringsSep "\n" lines;
in
{
  inherit primaryDisplay;

  mkNiriOutputs =
    host:
    lib.concatStringsSep "\n\n" (
      lib.filter (block: block != "") (map mkNiriOutputBlock (getDisplays host))
    );

  mkNoctaliaMonitorWidgets =
    { host
    , widgetsTemplate ? [ ]
    }:
    map
      (display: {
        inherit (display) name;
        widgets = widgetsTemplate;
      })
      (
        builtins.filter
          (display: (display.name or "") != "")
          (getDisplays host)
      );
}
