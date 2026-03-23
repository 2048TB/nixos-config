{ config
, lib
, mylib
, cpuVendor
, ...
}:
let
  hostCfg = config.my.host;
  isAmdCpu = cpuVendor == "amd";
  hibernateEnabled = hostCfg.resumeOffset != null;
  kvmModules = mylib.kvmModulesForVendor cpuVendor;
  resumeDevice =
    if config.fileSystems ? "/swap" && config.fileSystems."/swap" ? device
    then config.fileSystems."/swap".device
    else hostCfg.luksMapperDevice;
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
    kernelParams = lib.mkMerge [
      (lib.mkIf hibernateEnabled resumeKernelParams)
      # AMD P-State 主动模式：让内核直接驱动 CPU 频率调节，比 passive 模式响应更快
      (lib.mkIf isAmdCpu [ "amd_pstate=active" ])
    ];

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
    initrd = {
      systemd.enable = true;
      compressor = "zstd";
      compressorArgs = [ "-T0" ]; # 多线程压缩
    };
  };
}
