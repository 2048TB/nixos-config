{ repoRoot }:
let
  registry = builtins.fromTOML (builtins.readFile "${repoRoot}/nix/registry/systems.toml");

  sort = builtins.sort builtins.lessThan;

  loadVars = platform: host: import "${repoRoot}/nix/hosts/${platform}/${host}/vars.nix";

  enabledAttrNames =
    attrs: sort (builtins.filter (name: builtins.getAttr name attrs) (builtins.attrNames attrs));

  renderList = values: if values == [ ] then "none" else builtins.concatStringsSep ", " values;

  renderHostPath = platform: host: "nix/hosts/${platform}/${host}/vars.nix";

  renderPlatformLabel =
    platform: vars:
    if platform == "nixos" then "NixOS ${vars.formFactor}" else "Darwin ${vars.formFactor}";

  renderNotes =
    registryHost: vars:
    let
      noteParts = builtins.filter (value: value != "") [
        (if vars ? cpuVendor then "cpu=${vars.cpuVendor}" else "")
        (if vars ? gpuMode then "gpu=${vars.gpuMode}" else "")
        (if vars ? dockerMode then "docker=${vars.dockerMode}" else "")
        "deploy=${registryHost.deployUser}@${registryHost.deployHost}"
      ];
    in
    if noteParts == [ ] then "none" else builtins.concatStringsSep "; " noteParts;

  renderRow =
    platform: host:
    let
      registryHost = registry.${platform}.${host};
      vars = loadVars platform host;
      systemSoftware = enabledAttrNames (vars.software or { });
      homeSoftware = enabledAttrNames (vars.homeSoftware or { });
    in
    "| `${host}` | `${renderPlatformLabel platform vars}` | `${vars.system}` | `${renderList (vars.roles or [ ])}` | `${renderList systemSoftware}` | `${renderList homeSoftware}` | ${renderNotes registryHost vars} | `${renderHostPath platform host}` |";

  renderHostNotes =
    platform: host:
    let
      registryHost = registry.${platform}.${host};
      vars = loadVars platform host;
      noteLines = builtins.filter (line: line != null) [
        (if vars ? cpuVendor then "- `cpuVendor = \"${vars.cpuVendor}\"`" else null)
        (if vars ? gpuMode then "- `gpuMode = \"${vars.gpuMode}\"`" else null)
        (if vars ? dockerMode then "- `dockerMode = \"${vars.dockerMode}\"`" else null)
        (if vars ? formFactor then "- `formFactor = \"${vars.formFactor}\"`" else null)
        "- `roles = [ ${
          builtins.concatStringsSep ", " (builtins.map (role: "\"${role}\"") (vars.roles or [ ]))
        } ]`"
        "- `deploy = \"${registryHost.deployUser}@${registryHost.deployHost}\"`"
        "- 来源：`${renderHostPath platform host}`"
      ];
    in
    builtins.concatStringsSep "\n" (
      [
        "### `${host}`"
        ""
      ]
      ++ noteLines
      ++ [ "" ]
    );

  renderPlatform =
    platform:
    let
      hosts = sort (builtins.attrNames (registry.${platform} or { }));
    in
    {
      rows = map (host: renderRow platform host) hosts;
      notes = map (host: renderHostNotes platform host) hosts;
    };

  nixos = renderPlatform "nixos";
  darwin = renderPlatform "darwin";
in
builtins.concatStringsSep "\n" (
  [
    "# Host Matrix"
    ""
    "> Generated from `nix/registry/systems.toml` and `nix/hosts/*/*/vars.nix`. Do not edit manually."
    ""
    "当前主机能力矩阵，方便快速查看每台机器的 `roles`、系统层 `software`、用户层 `homeSoftware` 与关键差异。"
    ""
    "其中："
    "- `languageTools` 表示 Home Manager 补充语言工具模块"
    "- `roles` 表示系统功能角色"
    "- `formFactor` 只表示主机形态"
    ""
    "| Host | Platform | System | Roles | System software | Home software | Notes | Source |"
    "| --- | --- | --- | --- | --- | --- | --- | --- |"
  ]
  ++ nixos.rows
  ++ darwin.rows
  ++ [
    ""
    "## Host Notes"
    ""
  ]
  ++ nixos.notes
  ++ darwin.notes
)
