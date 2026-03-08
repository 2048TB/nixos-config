{ pkgs
, pkgsUnstable
, lib
, mylib
, myvars
, ...
}:
let
  roleFlags = mylib.roleFlags myvars;
  inherit (roleFlags) enableProvider appVpn enableSteam enableLibvirtd enableDocker;
  # App toggles (flat host vars, default true)
  enableWpsOffice = myvars.enableWpsOffice or true;
  enableZathura = myvars.enableZathura or true;
  enableSplayer = myvars.enableSplayer or true;
  enableTelegramDesktop = myvars.enableTelegramDesktop or true;
  enableLocalSend = myvars.enableLocalSend or true;

  # 仅在混合显卡（amd-nvidia-hybrid）时安装 GPU 加速相关软件
  gpuChoice = myvars.gpuMode or "auto";
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

  basePackageNames = lib.flatten [
    mylib.sharedPackageNames
    (import ./packages/cli.nix)
    (import ./packages/dev.nix)
    (import ./packages/desktop.nix)
    (import ./packages/media.nix)
    (import ./packages/archive.nix)
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
      ++ hybridPackages
      ++ lib.optional enableLocalSend pkgs.localsend
      ++ lib.optional enableZathura pkgs.zathura
      ++ lib.optional enableSplayer pkgs.splayer
      ++ lib.optional enableTelegramDesktop pkgs.telegram-desktop
      ++ lib.optional enableWpsOffice pkgs.wpsoffice
      ++ lib.optionals enableSteam gamingPackages
      ++ lib.optionals enableLibvirtd virtualisationPackages
      ++ lib.optionals enableDocker dockerPackages
      ++ lib.optional enableProvider appVpn pkgs.provider-app-vpn;
  };
}
