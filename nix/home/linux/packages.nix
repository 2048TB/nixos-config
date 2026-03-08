{ pkgs
, pkgsUnstable
, lib
, mylib
, myvars
, ...
}:
let
  fractionalScale = "1.25";
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
  isPrimeOffloadGpu = isHybridGpu || gpuChoice == "nvidia-prime";
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

  # WPS Office steam-run 包装器
  # 修复 NixOS 上 WPS 无法启动的问题（FHS 兼容性）
  # 参考：https://github.com/NixOS/nixpkgs/issues/125951
  # 额外注入 Qt 缩放变量，确保 XWayland 应用在分数缩放下保持可读尺寸。
  wpsRunWrapper = bin: lib.hiPrio (pkgs.writeShellScriptBin bin ''
    exec env \
      QT_AUTO_SCREEN_SCALE_FACTOR=0 \
      QT_ENABLE_HIGHDPI_SCALING=1 \
      QT_SCALE_FACTOR=${fractionalScale} \
      QT_SCALE_FACTOR_ROUNDING_POLICY=PassThrough \
      ${lib.getExe pkgs.steam-run} ${pkgs.wpsoffice}/bin/${bin} "$@"
  '');
  wpsWrappedBins = map wpsRunWrapper [ "wps" "et" "wpp" "wpspdf" ];
  # WPS 上游 desktop 使用绝对 /nix/store 路径，需改写为命令名以命中包装器。
  wpsDesktopOverride =
    desktopFile: bin:
    pkgs.runCommand "wps-desktop-override-${bin}" { } ''
      cp ${pkgs.wpsoffice}/share/applications/${desktopFile} "$out"
      sed -E -i 's|^Exec=.*/bin/${bin}(.*)$|Exec=${bin}\1|' "$out"
    '';

  nvidiaOffload = pkgs.writeShellApplication {
    name = "nvidia-offload";
    text = ''
      export __NV_PRIME_RENDER_OFFLOAD=1
      export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
      export __GLX_VENDOR_LIBRARY_NAME=nvidia
      export __VK_LAYER_NV_optimus=NVIDIA_only
      exec "$@"
    '';
  };

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
    (import ./packages/groups/cli.nix)
    (import ./packages/groups/dev.nix)
    (import ./packages/groups/desktop.nix)
    (import ./packages/groups/media.nix)
    (import ./packages/groups/archive.nix)
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
      ++ lib.optional isPrimeOffloadGpu nvidiaOffload
      ++ lib.optional enableProvider appVpn pkgs.provider-app-vpn
      ++ lib.optionals enableWpsOffice wpsWrappedBins; # WPS steam-run 包装器（覆盖原始二进制，修复启动问题）

    file = lib.optionalAttrs enableWpsOffice {
      ".local/share/applications/wps-office-wps.desktop".source =
        wpsDesktopOverride "wps-office-wps.desktop" "wps";
      ".local/share/applications/wps-office-et.desktop".source =
        wpsDesktopOverride "wps-office-et.desktop" "et";
      ".local/share/applications/wps-office-wpp.desktop".source =
        wpsDesktopOverride "wps-office-wpp.desktop" "wpp";
      ".local/share/applications/wps-office-pdf.desktop".source =
        wpsDesktopOverride "wps-office-pdf.desktop" "wpspdf";
      ".local/share/applications/wps-office-prometheus.desktop".source =
        wpsDesktopOverride "wps-office-prometheus.desktop" "wps";
    };
  };
}
