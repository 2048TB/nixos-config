{ pkgs
, pkgsUnstable
, lib
, mylib
, myvars
, osConfig ? null
, ...
}:
let
  hostCfg = import ../base/resolve-host.nix { inherit myvars osConfig; };
  packageGroups = import ./package-groups.nix;
  packageGroupOrder = [
    "cli"
    "dev"
    "desktop"
    "media"
    "archive"
  ];
  enableProvider appVpn = hostCfg.enableProvider appVpn or false;
  enableSteam = hostCfg.enableSteam or false;
  enableLibvirtd = hostCfg.enableLibvirtd or false;
  enableDocker = hostCfg.enableDocker or false;
  # App toggles (flat host vars, default false; aligned with nix/modules/core/options.nix)
  enableWpsOffice = hostCfg.enableWpsOffice or false;
  enableZathura = hostCfg.enableZathura or false;
  enableSplayer = hostCfg.enableSplayer or false;
  enableTelegramDesktop = hostCfg.enableTelegramDesktop or false;
  enableLocalSend = hostCfg.enableLocalSend or false;
  wpsOfficePackage = pkgs.wpsoffice;

  # 仅在混合显卡（amd-nvidia-hybrid）时安装 GPU 加速相关软件
  gpuChoice = hostCfg.gpuMode or "auto";
  isHybridGpu = gpuChoice == "amd-nvidia-hybrid";
  ollamaVulkan = pkgs.ollama or null;
  tensorflowCudaPkg = pkgs.python3Packages.tensorflowWithCuda or null;
  tensorflowCudaEnv =
    if tensorflowCudaPkg != null
    then pkgs.python3.withPackages (_: [ tensorflowCudaPkg ])
    else null;
  hashcatPkg = pkgs.hashcat or null;
  hybridPackages = lib.optionals isHybridGpu (
    lib.optional (ollamaVulkan != null) ollamaVulkan
    ++ lib.optional (tensorflowCudaEnv != null) tensorflowCudaEnv
    ++ lib.optional (hashcatPkg != null) hashcatPkg
  );

  cherryStudioPackage = pkgsUnstable.cherry-studio;
  gamingPackages = with pkgs; [
    mangohud
    umu-launcher
    bbe
    wineWowPackages.stable # 原：stagingFull（避免触发本地编译）
    winetricks
    protonplus
  ];
  virtualisationPackages = with pkgs; [
    virt-viewer
    spice-gtk
    qemu_kvm
  ];
  dockerPackages = with pkgs; [
    docker-compose # Docker 编排工具
    dive # Docker 镜像分析
    lazydocker # Docker TUI 管理器
  ];
  # 仅将 MinGW 交叉编译器的可执行文件加入 user profile，避免与本机 gcc 的文档路径冲突告警。
  mingwToolchainBinOnly = pkgs.buildEnv {
    name = "mingw-w64-toolchain-bin-only";
    paths = [ pkgs.pkgsCross.mingwW64.stdenv.cc ];
    pathsToLink = [ "/bin" ];
  };
  devToolchainPackages = with pkgs; [
    neovim
    (rust-bin.stable.latest.default.override {
      targets = [ "x86_64-pc-windows-gnu" ];
    })
    rust-bin.stable.latest.rust-analyzer
    mingwToolchainBinOnly
    zig
    zls
    go
    gcc
    gopls
    delve
    gotools
    nodejs
    nodePackages.typescript
    nodePackages.typescript-language-server
    python3
    python3Packages.pip
    pyright
    ruff
    black
    uv
  ];

  basePackageNames = lib.flatten [
    mylib.sharedPackageNames
    (map (groupName: packageGroups.${groupName}) packageGroupOrder)
  ];
  basePackageSelection = mylib.resolvePackagesByName pkgs basePackageNames;
  basePackages = basePackageSelection.packages ++ [ cherryStudioPackage ];
in
{
  warnings = lib.optionals (basePackageSelection.skippedNames != [ ]) [
    "Linux skipped unavailable packages: ${lib.concatStringsSep ", " basePackageSelection.skippedNames}"
  ];

  home = {
    packages = basePackages
      ++ devToolchainPackages
      ++ hybridPackages
      ++ lib.optional enableLocalSend pkgs.localsend
      ++ lib.optional enableZathura pkgs.zathura
      ++ lib.optional enableSplayer pkgs.splayer
      ++ lib.optional enableTelegramDesktop pkgs.telegram-desktop
      ++ lib.optional enableWpsOffice wpsOfficePackage
      ++ lib.optionals enableSteam gamingPackages
      ++ lib.optionals enableLibvirtd virtualisationPackages
      ++ lib.optionals enableDocker dockerPackages
      ++ lib.optional enableProvider appVpn pkgs.provider-app-vpn;
  };
}
