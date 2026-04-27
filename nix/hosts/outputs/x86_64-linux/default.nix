{ lib, mylib, inputs, system, mkApp, appRepoPreamble, ... }@args:
let
  common = import ../common.nix { inherit lib mylib; };
  hostsRoot = mylib.relativeToRoot "nix/hosts/nixos";
  registryState = common.mkRegistryState {
    kind = "nixos";
    inherit hostsRoot system;
    requiredFiles = [
      "hardware.nix"
      "hardware-modules.nix"
      "disko.nix"
      "vars.nix"
    ];
  };
  inherit (registryState) hostNames;

  mkHostData =
    name:
    let
      hostDir = "nix/hosts/nixos/${name}";
      hostVarsPath = mylib.relativeToRoot "${hostDir}/vars.nix";
      hostChecksPath = mylib.relativeToRoot "${hostDir}/checks.nix";
      sharedChecksPath = mylib.relativeToRoot "nix/hosts/nixos/_shared/checks.nix";
      generatedDesktopChecksPath = mylib.relativeToRoot "nix/hosts/nixos/_shared/generated-desktop-checks.nix";
      hostMyvars = import hostVarsPath;
      hostRegistry = mylib.hostRegistryEntry "nixos" name;
      hostCtx = mylib.mkNixosHost (args // {
        inherit name hostMyvars hostRegistry;
      });
      hostCheckArgs = hostCtx // { inherit (args) lib mylib; };
      hostChecks =
        (import sharedChecksPath hostCheckArgs)
        // (import generatedDesktopChecksPath hostCheckArgs)
        // (mylib.importIfExists hostChecksPath hostCheckArgs);
    in
    mylib.mkHostDataEntry {
      configAttrName = "nixosConfigurations";
      hostSystemAttr = "nixosSystem";
      inherit hostCtx hostChecks;
    };

  data = mylib.mapNamesToAttrs hostNames mkHostData;
  dataWithoutPaths = builtins.attrValues data;
  nixosConfigurations = mylib.mergeAttrFromList "nixosConfigurations" dataWithoutPaths;
  mainUsers = mylib.mergeAttrFromList "mainUsers" dataWithoutPaths;
  resolvedHostNames = builtins.attrNames nixosConfigurations;
  homeConfigurations = common.mkHomeConfigurations {
    configurations = nixosConfigurations;
    inherit mainUsers system;
  };

  hostEvalTests = common.mkStandardEvalTests {
    configurations = nixosConfigurations;
    inherit mainUsers system;
    hostNames = resolvedHostNames;
    homeRoot = "/home";
    extraTests = {
      kernel =
        common.mapHostValuesByPath [ "config" "boot" "kernelPackages" "kernel" "system" ] nixosConfigurations
        == common.mkExpectedAttrSet resolvedHostNames system;
    };
  };

  pkgs = import inputs.nixpkgs {
    inherit system;
    config.allowUnfreePredicate = mylib.allowUnfreePredicate;
  };
  hostRegistryLib = import ../../../lib/host-registry.nix { inherit lib; };
  registryRequiredKeyCheck =
    let
      incompleteState = hostRegistryLib.mkRegistryState {
        hostRegistry = {
          system = "x86_64-linux";
          desktopSession = false;
          desktopProfile = "none";
          kind = "server";
          formFactor = "headless";
        };
        hostMyvars = {
          gpuMode = "none";
        };
      };
      requiredFailure = builtins.tryEval (
        hostRegistryLib.assertCommonRegistry {
          registryPath = "nix/hosts/registry/systems.toml";
          hostDir = "nix/hosts/nixos/evaltest-missing-required";
          hostName = "nixos.evaltest-missing-required";
          state = incompleteState;
        }
      );
    in
    {
      required-key-list =
        incompleteState.missingRequiredRegistryKeys == [
          "tags"
          "gpuVendors"
          "displays"
        ];
      required-keys =
        !requiredFailure.success;
    };
  missingHomeUserCheck =
    let
      missingHomeConfigurations = common.mkHomeConfigurations {
        system = "x86_64-linux";
        mainUsers.evalhost = "alice";
        configurations.evalhost.config.home-manager.users = { };
      };
      missingHomeUserNamesResult = builtins.tryEval (builtins.attrNames missingHomeConfigurations);
      missingHomeUserResult = builtins.tryEval
        missingHomeConfigurations."alice@evalhost".config.home.activationPackage;
      presentHomeConfigurations = common.mkHomeConfigurations {
        system = "x86_64-linux";
        mainUsers.evalhost = "alice";
        configurations.evalhost.config.home-manager.users.alice.home.activationPackage = "ok";
      };
    in
    {
      home-config-missing-user =
        !missingHomeUserNamesResult.success
        && !missingHomeUserResult.success;
      home-config-output-name =
        builtins.hasAttr "alice@evalhost" presentHomeConfigurations;
    };
  headlessHomeCheck =
    let
      baseHeadlessMyvars = import (mylib.relativeToRoot "nix/hosts/nixos/zly/vars.nix");
      headlessHostCtx = mylib.mkNixosHost (args // {
        name = "zly";
        hostMyvars = baseHeadlessMyvars // {
          roles = [ ];
          gpuMode = "none";
          enableWpsOffice = false;
          enableZathura = false;
          enableSplayer = false;
          enableTelegramDesktop = false;
          enableLocalSend = false;
          enableAntigravity = false;
        };
        hostRegistry = {
          system = "x86_64-linux";
          desktopSession = false;
          desktopProfile = "none";
          kind = "server";
          formFactor = "headless";
          tags = [ ];
          gpuVendors = [ ];
          displays = [ ];
        };
      });
      headlessHmCfg = headlessHostCtx.nixosSystem.config.home-manager.users.${headlessHostCtx.mainUser};
      headlessServices = headlessHmCfg.systemd.user.services or { };
      headlessConfigFiles = headlessHmCfg.xdg.configFile or { };
      headlessPackageNames = map (pkg: builtins.unsafeDiscardStringContext (lib.getName pkg)) headlessHmCfg.home.packages;
      unexpectedHeadlessGuiPackages = lib.intersectLists
        headlessPackageNames
        [
          "google-chrome"
          "vscode"
          "nautilus"
          "ghostty"
          "foot"
          "fuzzel"
          "pavucontrol"
        ];
    in
    {
      headless-home-no-gui-services =
        !(builtins.hasAttr "playerctld" headlessServices)
        && !(builtins.hasAttr "udiskie" headlessServices)
        && !(builtins.hasAttr "polkit-gnome-authentication-agent-1" headlessServices)
        && !(builtins.hasAttr "aria2" headlessServices);
      headless-home-no-noctalia =
        !(headlessHmCfg.programs.noctalia-shell.enable or false);
      headless-home-no-portal =
        !(headlessHmCfg.xdg.portal.enable or false);
      headless-home-no-niri-noctalia-configs =
        !(builtins.hasAttr "niri/config.kdl" headlessConfigFiles)
        && !(builtins.hasAttr "niri/outputs.kdl" headlessConfigFiles)
        && !(builtins.hasAttr "noctalia" headlessConfigFiles);
      headless-home-no-gui-packages =
        unexpectedHeadlessGuiPackages == [ ];
    };
  pkgsMl = import inputs.nixpkgs {
    inherit system;
    config = {
      inherit (mylib) allowUnfreePredicate;
      cudaSupport = true;
    };
  };
  mkAppLocal = mkApp pkgs;
  mkEvalCheck = common.mkEvalCheck pkgs;
  evalCheckSpecs =
    common.mkEvalCheckSpecs "" (
      hostEvalTests
      // registryRequiredKeyCheck
      // missingHomeUserCheck
      // headlessHomeCheck
    );
  platformApps.${system} = {
    install = mkAppLocal "install" "Install Linux host on Live ISO with disko+nixos-install" ''
      ${appRepoPreamble}
      host="''${NIXOS_HOST:-}"
      if [ -z "$host" ]; then
        echo "error: NIXOS_HOST is required for nix run .#install" >&2
        echo "hint: NIXOS_HOST=${builtins.head resolvedHostNames} NIXOS_DISK_DEVICE=/dev/nvme0n1 nix run .#install" >&2
        exit 2
      fi
      exec ${pkgs.just}/bin/just host="$host" disk="''${NIXOS_DISK_DEVICE:-/dev/nvme0n1}" install
    '';
  };
  evalTestChecks.${system} = mylib.specsToAttrs evalCheckSpecs mkEvalCheck;

  preCommitCheck = inputs.pre-commit-hooks.lib.${system}.run {
    src = mylib.relativeToRoot ".";
    hooks = {
      nixpkgs-fmt.enable = true;
      statix.enable = true;
      deadnix.enable = true;
    };
  };
  formatSanityCheck = pkgs.runCommand "format-sanity"
    {
      nativeBuildInputs = [
        pkgs.just
        pkgs.ripgrep
        (pkgs.python3.withPackages (ps: [ ps.pyyaml ]))
      ];
    } ''
    cp -R ${mylib.relativeToRoot "."} repo
    bash repo/nix/scripts/admin/check-format-sanity.sh --repo "$PWD/repo"
    touch "$out"
  '';

  platformChecks.${system} = {
    pre-commit-check = preCommitCheck;
    format-sanity = formatSanityCheck;
  };

  defaultHost = builtins.head resolvedHostNames;
  mlPython = pkgsMl.python312.override {
    packageOverrides = _: prev: {
      torch = prev."torch-bin";
      pytorch = prev."pytorch-bin";
      triton = prev."triton-bin";
      openai-triton = prev."openai-triton-bin";
    };
  };
  mlCudaToolkit = pkgsMl.cudaPackages.cudatoolkit;
  mlCudnn = pkgsMl.cudaPackages.cudnn;
  mlNccl = pkgsMl.cudaPackages.nccl;
  mlPythonPackages = mlPython.pkgs;
  mlCudaLibPath = pkgsMl.lib.makeLibraryPath [
    mlCudaToolkit
    mlCudnn
    mlNccl
    pkgsMl.stdenv.cc.cc
    pkgsMl.zlib
  ];
  mlCudaRuntimeLibPath = "/run/opengl-driver/lib:/run/current-system/sw/lib:${mlCudaLibPath}";
  mlPythonEnv = mlPython.withPackages (_: with mlPythonPackages; [
    torch
    transformers
    datasets
    accelerate
    peft
    trl
    safetensors
    sentencepiece
    protobuf
    evaluate
    tensorboard
    ipykernel
    jupyterlab
  ]);
  platformDevShells.${system} = {
    default = pkgs.mkShell {
      name = "nixos-config-dev";
      packages = with pkgs; [
        nix-tree
        just
        check-jsonschema
        shellcheck
        shfmt
        nixpkgs-fmt
        statix
        deadnix
      ] ++ preCommitCheck.enabledPackages;
      shellHook = ''
        ${preCommitCheck.shellHook}
        export OPENSSL_INCLUDE_DIR="${pkgs.openssl.dev}/include"
        export OPENSSL_LIB_DIR="${pkgs.openssl.out}/lib"
        export OPENSSL_DIR="${pkgs.openssl.dev}"
        if [ -d .githooks ] && [ "$(git config core.hooksPath 2>/dev/null)" != ".githooks" ]; then
          git config core.hooksPath .githooks
        fi
        echo "NixOS config dev shell"
        echo "nixos-rebuild switch --flake .#${defaultHost}"
        echo "nixos-rebuild test --flake .#${defaultHost}"
      '';
    };

    ml = pkgsMl.mkShell {
      name = "nixos-ml-dev";
      packages = with pkgsMl; [
        mlPythonEnv
        uv
        git
        git-lfs
        cmake
        ninja
        pkg-config
        cudaPackages.cuda_nvcc
        mlCudaToolkit
        mlCudnn
        mlNccl
      ];
      shellHook = ''
        export CUDA_PATH="${mlCudaToolkit}"
        export CUDA_HOME="${mlCudaToolkit}"
        export CUDA_ROOT="${mlCudaToolkit}"
        export CUDNN_PATH="${mlCudnn}"
        export CUDNN_INCLUDE_DIR="${mlCudnn}/include"
        export CUDNN_LIB_DIR="${mlCudnn}/lib"
        export NCCL_ROOT_DIR="${mlNccl}"
        export NCCL_LIB_DIR="${mlNccl}/lib"
        export OPENSSL_INCLUDE_DIR="${pkgsMl.openssl.dev}/include"
        export OPENSSL_LIB_DIR="${pkgsMl.openssl.out}/lib"
        export OPENSSL_DIR="${pkgsMl.openssl.dev}"
        export LD_LIBRARY_PATH="${mlCudaRuntimeLibPath}:''${LD_LIBRARY_PATH:-}"
        export HF_HOME="''${HOME}/.cache/huggingface"
        export TRANSFORMERS_CACHE="''${HF_HOME}/hub"
        export TORCH_HOME="''${HOME}/.cache/torch"
        # 若需编译 CUDA 扩展（如 flash-attn），请根据实际显卡架构按需设置
        # export TORCH_CUDA_ARCH_LIST="8.9"
        echo "ML shell ready"
        echo "python --version"
        echo "python -c 'import torch; print(torch.__version__, torch.cuda.is_available())'"
      '';
    };
  };

  platformFormatter.${system} = pkgs.nixpkgs-fmt;
in
assert common.assertRegistryState
{
  state = registryState;
  registryKey = "nixos";
  kindDisplay = "NixOS";
  hostsPath = "nix/hosts/nixos";
  inherit system;
};
{
  inherit data;
  registeredHosts = resolvedHostNames;
  inherit nixosConfigurations homeConfigurations;
  apps = platformApps;
  checks = mylib.mergeAttrFromListWithExtra "checks" dataWithoutPaths [
    evalTestChecks
    platformChecks
  ];
  devShells = mylib.mergeAttrFromListWithExtra "devShells" dataWithoutPaths [ platformDevShells ];
  formatter = mylib.mergeAttrFromListWithExtra "formatter" dataWithoutPaths [ platformFormatter ];
}
