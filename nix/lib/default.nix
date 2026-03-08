{ lib }:
let
  nixosSystem =
    { inputs
    , system
    , specialArgs
    , modules
    , mainUser
    , homeModules ? [ ]
    , ...
    }:
    let
      inherit (inputs) nixpkgs home-manager;
    in
    nixpkgs.lib.nixosSystem {
      inherit system specialArgs;
      modules =
        modules
        ++ lib.optionals (homeModules != [ ]) [
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "bak";
              extraSpecialArgs = specialArgs;
              users.${mainUser}.imports = homeModules;
            };
          }
        ];
    };

  macosSystem =
    { inputs
    , system
    , specialArgs
    , modules
    , mainUser
    , homeModules ? [ ]
    , ...
    }:
    let
      inherit (inputs) nix-darwin nixpkgs-darwin home-manager;
    in
    nix-darwin.lib.darwinSystem {
      inherit system specialArgs;
      modules =
        modules
        ++ [
          (
            _:
            {
              nixpkgs.pkgs = import nixpkgs-darwin {
                inherit system;
                config.allowUnfree = true;
              };
            }
          )
          {
            # home-manager's nix-darwin bridge resolves home.homeDirectory from
            # users.users.<name>.home; ensure it is defined.
            users.users.${mainUser}.home = lib.mkDefault "/Users/${mainUser}";
          }
        ]
        ++ lib.optionals (homeModules != [ ]) [
          home-manager.darwinModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "bak";
              extraSpecialArgs = specialArgs;
              users.${mainUser} = {
                imports = homeModules;
                # Keep Darwin HM user attrs defined at the assembly layer to avoid
                # null defaults leaking into eval-time checks.
                home = {
                  username = lib.mkDefault mainUser;
                  homeDirectory = lib.mkDefault "/Users/${mainUser}";
                  stateVersion = lib.mkDefault (specialArgs.myvars.homeStateVersion or "25.11");
                };
              };
            };
          }
        ];
    };

  mkNixosHost = import ./mkNixosHost.nix { inherit lib; };
  mkDarwinHost = import ./mkDarwinHost.nix { inherit lib; };
in
rec {
  inherit nixosSystem macosSystem;
  inherit mkNixosHost mkDarwinHost;

  hasNonEmptyString =
    attrs: key:
    builtins.hasAttr key attrs
    && builtins.isString attrs.${key}
    && attrs.${key} != "";

  hasPositiveInt =
    attrs: key:
    builtins.hasAttr key attrs
    && builtins.isInt attrs.${key}
    && attrs.${key} > 0;

  namesNotMatching =
    pattern: names:
    builtins.filter (name: builtins.match pattern name == null) names;

  mapNamesToAttrs =
    names: mkValue:
    builtins.listToAttrs (
      map
        (name: {
          inherit name;
          value = mkValue name;
        })
        names
    );

  mergeAttrFromList =
    attrName: attrsList:
    mergeRecursiveAttrsList (map (it: it.${attrName} or { }) attrsList);

  mergeAttrFromListWithExtra =
    attrName: attrsList: extraAttrs:
    mergeRecursiveAttrsList (
      (map (it: it.${attrName} or { }) attrsList)
      ++ extraAttrs
    );

  pathIfExists = path: if builtins.pathExists path then path else null;

  importIfExists = path: args: if builtins.pathExists path then import path args else { };

  mkHostDataEntry =
    { configAttrName
    , hostSystemAttr
    , hostCtx
    , hostChecks ? { }
    }:
    {
      ${configAttrName}.${hostCtx.name} = hostCtx.${hostSystemAttr};
      checks.${hostCtx.system} = hostChecks;
      mainUsers.${hostCtx.name} = hostCtx.mainUser;
    };

  specsToAttrs =
    specs: mkValue:
    builtins.listToAttrs (
      map
        (spec: {
          name = spec.name;
          value = mkValue spec;
        })
        specs
    );

  scanPaths =
    path:
    builtins.map (name: (path + "/${name}")) (
      builtins.attrNames (
        lib.attrsets.filterAttrs
          (
            name: type:
            (
              type == "directory"
              && builtins.pathExists (path + "/${name}/default.nix")
            )
            || (
              name != "default.nix"
              && lib.strings.hasSuffix ".nix" name
            )
          )
          (builtins.readDir path)
      )
    );

  mergeRecursiveAttrsList = attrsList: lib.foldl' lib.recursiveUpdate { } attrsList;

  discoverHostNamesBy =
    hostsRoot: requiredFiles:
    let
      hostsDir = builtins.readDir hostsRoot;
    in
    builtins.filter
      (
        name:
        hostsDir.${name} == "directory"
        && builtins.all (file: builtins.pathExists (hostsRoot + "/${name}/${file}")) requiredFiles
      )
      (builtins.attrNames hostsDir);

  # Use paths relative to the repository root.
  relativeToRoot = lib.path.append ../../.;

  hostMetaSchema = {
    defaultRoles = [ "desktop" ];
    defaultDockerMode = "rootless";

    allowedCpuVendors = [
      "auto"
      "amd"
      "intel"
    ];

    allowedGpuModes = [
      "auto"
      "none"
      "amd"
      "amdgpu"
      "nvidia"
      "nvidia-prime"
      "modesetting"
      "amd-nvidia-hybrid"
    ];

    allowedDockerModes = [
      "rootless"
      "rootful"
    ];

    knownHostRoles = [
      "desktop"
      "gaming"
      "vpn"
      "virt"
      "container"
    ];

    optionalBoolOptions = [
      "enableHibernate"
      "enableGpuSpecialisation"
      "enableBluetoothRfkillUnblock"
      "enableAggressiveApparmorKill"
      "enableWaybarBacklight"
      "enableWaybarBattery"
      "enableNvidiaContainerToolkit"
      "acceptFlakeConfig"
      "enableMullvadVpn"
      "enableLibvirtd"
      "enableDocker"
      "enableFlatpak"
      "enableSteam"
      "enableWpsOffice"
      "enableZathura"
      "enableSplayer"
      "enableTelegramDesktop"
      "enableLocalSend"
    ];

    optionalStringOptions = [
      "rootTmpfsSize"
      "journaldSystemMaxUse"
      "journaldRuntimeMaxUse"
      "gcRetentionDays"
      "diskDevice"
    ];

    optionalNullableStringOptions = [
      "intelBusId"
      "amdgpuBusId"
      "nvidiaBusId"
    ];
  };

  roleFlags = myvars:
    let
      hostRoles = myvars.roles or hostMetaSchema.defaultRoles;
      hasRole = role: builtins.elem role hostRoles;
      dockerMode = myvars.dockerMode or hostMetaSchema.defaultDockerMode;
    in
    {
      inherit hostRoles hasRole dockerMode;
      enableMullvadVpn = myvars.enableMullvadVpn or (hasRole "vpn");
      enableLibvirtd = myvars.enableLibvirtd or (hasRole "virt");
      enableDocker = myvars.enableDocker or (hasRole "container");
      enableFlatpak = myvars.enableFlatpak or (hasRole "desktop");
      enableSteam = myvars.enableSteam or (hasRole "gaming");
      useRootfulDocker = dockerMode == "rootful";
      useRootlessDocker = dockerMode == "rootless";
    };

  kvmModulesForVendor = vendor:
    if vendor == "amd" then [ "kvm-amd" ]
    else if vendor == "intel" then [ "kvm-intel" ]
    else [ "kvm-amd" "kvm-intel" ];

  mkLogFilteredLauncher =
    pkgs: name: executable: filters:
    let
      mkSedDeleteExpr = pattern:
        let
          escapedPattern = lib.replaceStrings [ "/" ] [ "\\/" ] pattern;
        in
        "/${escapedPattern}/d";
      sedDeleteArgs =
        lib.concatMapStringsSep " \\\n"
          (pattern: "          -e ${lib.escapeShellArg (mkSedDeleteExpr pattern)}")
          filters;
    in
    pkgs.writeShellScriptBin name ''
            set -euo pipefail
            sedBin="${pkgs.gnused}/bin/sed"

            set +e
            ${executable} "$@" 2>&1 \
              | "$sedBin" -u -E \
      ${sedDeleteArgs}
              >&2
            status="''${PIPESTATUS[0]}"
            set -e
            exit "$status"
    '';
}
