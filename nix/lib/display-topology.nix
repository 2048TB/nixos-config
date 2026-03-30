{ lib }:
let
  getDisplays = host: host.displays or [ ];
  optionalString = condition: value: if condition then value else "";

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

  renderKanshiMode =
    display:
    let
      width = display.width or null;
      height = display.height or null;
      refresh = display.refresh or null;
    in
    if width == null || height == null then null
    else if refresh == null then "${toString width}x${toString height}"
    else "${toString width}x${toString height}@${toString refresh}Hz";

  normalizeScale =
    scale:
    if scale == null then null
    else if builtins.isInt scale then scale * 1.0
    else scale;

  orderedDisplays =
    host:
    let
      displays = getDisplays host;
      primaryDisplays = builtins.filter (display: display.primary or false) displays;
      secondaryDisplays = builtins.filter (display: !(display.primary or false)) displays;
    in
    primaryDisplays ++ secondaryDisplays;

  mkKanshiOutputs =
    host:
    let
      displays = orderedDisplays host;
      build =
        state: display:
        let
          identifier = outputIdentifier display;
          width = display.width or 0;
          mode = renderKanshiMode display;
          scale = normalizeScale (display.scale or null);
          output =
            {
              criteria = identifier;
              status = "enable";
            }
            // lib.optionalAttrs (mode != null) { inherit mode; }
            // lib.optionalAttrs (scale != null) { inherit scale; }
            // lib.optionalAttrs ((builtins.length displays) > 1) { position = "${toString state.x},0"; };
        in
        {
          x = state.x + width;
          outputs = state.outputs ++ lib.optional (identifier != null) output;
        };
    in
    (builtins.foldl' build { x = 0; outputs = [ ]; } displays).outputs;

  mkKanshiSettings =
    host:
    let
      outputs = mkKanshiOutputs host;
    in
    if outputs == [ ] then [ ] else [
      {
        profile.name = "default";
        profile.outputs = outputs;
      }
    ];

  kanshiOutputToString =
    { criteria
    , status ? null
    , mode ? null
    , position ? null
    , scale ? null
    , transform ? null
    , adaptiveSync ? null
    , alias ? null
    , ...
    }:
    ''output "${criteria}"''
    + optionalString (status != null) " ${status}"
    + optionalString (mode != null) " mode ${mode}"
    + optionalString (position != null) " position ${position}"
    + optionalString (scale != null) " scale ${toString scale}"
    + optionalString (transform != null) " transform ${transform}"
    + optionalString (adaptiveSync != null) " adaptive_sync ${if adaptiveSync then "on" else "off"}"
    + optionalString (alias != null) " alias \$${alias}";

  kanshiProfileToString =
    { name ? ""
    , outputs ? [ ]
    , exec ? [ ]
    , ...
    }:
    ''
      profile ${name} {
        ${lib.concatStringsSep "\n  " (map kanshiOutputToString outputs ++ map (cmd: "exec ${cmd}") exec)}
      }
    '';

  kanshiDirectiveToString =
    directive:
    if directive ? profile then
      kanshiProfileToString directive.profile
    else if directive ? output then
      kanshiOutputToString directive.output
    else if directive ? include then
      ''include "${directive.include}"''
    else
      throw "Unknown kanshi directive keys: ${lib.concatStringsSep ", " (builtins.attrNames directive)}";
in
{
  inherit primaryDisplay;

  inherit mkKanshiSettings;

  mkKanshiConfig =
    host:
    lib.concatStringsSep "\n" (map kanshiDirectiveToString (mkKanshiSettings host));
}
