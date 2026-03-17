{ pkgs
, pkgsUnstable
, lib
, mylib
, mytheme
, myvars
, osConfig ? null
, ...
}:
let
  hostCfg = import ../base/resolve-host.nix { inherit myvars osConfig; };
  sessionTools = import ../../lib/session-tools.nix { inherit pkgs mytheme; };
  roleFlags = mylib.roleFlags hostCfg;
  packageGroups = import ./package-groups.nix;
  packageGroupOrder = [
    "cli"
    "dev"
    "desktop"
    "media"
    "archive"
  ];
  inherit (roleFlags) enableMullvadVpn enableSteam enableLibvirtd enableDocker;
  # App toggles stay in host vars and are consumed only by Home Manager.
  enableWpsOffice = myvars.enableWpsOffice or false;
  enableZathura = myvars.enableZathura or false;
  enableSplayer = myvars.enableSplayer or false;
  enableTelegramDesktop = myvars.enableTelegramDesktop or false;
  enableLocalSend = myvars.enableLocalSend or false;
  wpsOfficePackage = pkgs.wpsoffice;

  # 仅在混合显卡（amd-nvidia-hybrid）时安装 GPU 加速相关软件
  gpuChoice = hostCfg.gpuMode or "modesetting";
  isHybridGpu = gpuChoice == "amd-nvidia-hybrid";
  ollamaVulkan = pkgs.ollama or null;
  tensorflowCudaPkg = pkgs.python3Packages.tensorflowWithCuda or null;
  tensorflowCudaEnv =
    if tensorflowCudaPkg != null
    then pkgs.python3.withPackages (_: [ tensorflowCudaPkg ])
    else null;
  primaryPythonPackage =
    if tensorflowCudaEnv != null
    then tensorflowCudaEnv
    else pkgs.python3;
  hashcatPkg = pkgs.hashcat or null;
  hybridPackages = lib.optionals isHybridGpu (
    lib.optional (ollamaVulkan != null) ollamaVulkan
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
  wlogoutMenu = sessionTools.mkWlogoutMenuPackage { };
  lockScreen = sessionTools.mkLockScreenPackage { };
  riverCliphistMenu = pkgs.writeShellApplication {
    name = "river-cliphist-menu";
    runtimeInputs = with pkgs; [ cliphist fuzzel wl-clipboard ];
    text = builtins.readFile ../../scripts/session/cliphist-menu.sh;
  };
  waybarTemperatureStatus = pkgs.writeShellApplication {
    name = "waybar-temperature-status";
    runtimeInputs = with pkgs; [ coreutils ];
    text = builtins.readFile ../../scripts/session/waybar-temperature.sh;
  };
  takeScreenshot = pkgs.writeShellApplication {
    name = "take-screenshot";
    runtimeInputs = with pkgs; [ coreutils grim slurp wl-clipboard ];
    text = builtins.readFile ../../scripts/session/take-screenshot.sh;
  };
  wallpaperNext = pkgs.writeShellApplication {
    name = "wallpaper-next";
    runtimeInputs = with pkgs; [ coreutils ];
    text = builtins.readFile ../../scripts/session/wallpaper-next.sh;
  };
  # 仅将 MinGW 交叉编译器的可执行文件加入 user profile，避免与本机 gcc 的文档路径冲突告警。
  mingwToolchainBinOnly = pkgs.buildEnv {
    name = "mingw-w64-toolchain-bin-only";
    paths = [ pkgs.pkgsCross.mingwW64.stdenv.cc ];
    pathsToLink = [ "/bin" ];
  };
  # clang-wrapper 会提供 cc/c++/cpp 通用别名，和 gcc-wrapper 在 HM buildEnv 中冲突。
  # 这里保留 clang/clang++ 等专用入口，只移除通用兼容名，避免牺牲任一工具链。
  clangWithoutCompatAliases = pkgs.symlinkJoin {
    name = "clang-without-compat-aliases";
    paths = [ pkgs.clang ];
    postBuild = ''
      rm -f "$out/bin/cc" "$out/bin/c++" "$out/bin/cpp"
    '';
  };
  devToolchainPackages = with pkgs; [
    neovim
    (rust-bin.stable.latest.default.override {
      targets = [ "x86_64-pc-windows-gnu" ];
    })
    rust-bin.stable.latest.rust-analyzer
    mingwToolchainBinOnly
    clangWithoutCompatAliases
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
    primaryPythonPackage
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
      ++ [
        wlogoutMenu
        lockScreen
        riverCliphistMenu
        waybarTemperatureStatus
        takeScreenshot
        wallpaperNext
      ]
      ++ devToolchainPackages
      ++ hybridPackages
      ++ lib.optional enableLocalSend pkgs.localsend
      ++ lib.optional enableZathura pkgs.zathura
      ++ lib.optional enableSplayer pkgs.splayer
      ++ lib.optional enableTelegramDesktop pkgsUnstable.telegram-desktop
      ++ lib.optional enableWpsOffice wpsOfficePackage
      ++ lib.optionals enableSteam gamingPackages
      ++ lib.optionals enableLibvirtd virtualisationPackages
      ++ lib.optionals enableDocker dockerPackages
      ++ lib.optional enableMullvadVpn pkgs.mullvad-vpn;
  };
}
