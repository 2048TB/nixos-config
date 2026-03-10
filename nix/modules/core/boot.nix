{ config
, lib
, mylib
, derivedCpuVendor
, ...
}:
let
  hostCfg = config.my.host;
  cpuVendor = derivedCpuVendor;
  hibernateEnabled = hostCfg.resumeOffset != null;
  kvmModules = mylib.kvmModulesForVendor cpuVendor;
  luksMapperDevice = "/dev/mapper/${hostCfg.luksName}";
  resumeDevice =
    if config.fileSystems ? "/swap" && config.fileSystems."/swap" ? device
    then config.fileSystems."/swap".device
    else luksMapperDevice;
  resumeKernelParams =
    if hibernateEnabled
    then [ "resume_offset=${toString hostCfg.resumeOffset}" ]
    else [ ];
in
{
  boot = {
    # 引导加载器
    loader = {
      systemd-boot = {
        enable = lib.mkDefault true;
        configurationLimit = lib.mkDefault 15;
        consoleMode = lib.mkDefault "max";
      };
      efi.canTouchEfiVariables = true;
    };

    # 安全启动（lanzaboote）- 默认关闭
    lanzaboote = {
      enable = lib.mkDefault false;
      pkiBundle = "/etc/secureboot";
    };

    # KVM 内核模块（AMD/Intel）
    kernelModules = kvmModules;
    resumeDevice = lib.mkIf hibernateEnabled (lib.mkDefault resumeDevice);
    kernelParams = lib.mkIf hibernateEnabled resumeKernelParams;

    # 支持的文件系统
    supportedFilesystems = [
      "ext4"
      "btrfs"
      "xfs"
      "ntfs"
      "fat"
      "vfat"
      "exfat"
    ];

    # preservation 需要 initrd 的 systemd
    initrd.systemd.enable = true;
  };
}
