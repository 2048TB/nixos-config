{ config
, lib
, mylib
, ...
}:
let
  hostCfg = config.my.host;
  inherit (hostCfg) cpuVendor enableHibernate;
  kvmModules = mylib.kvmModulesForVendor cpuVendor;
  resumeDevice =
    if config.fileSystems ? "/swap" && config.fileSystems."/swap" ? device
    then config.fileSystems."/swap".device
    else "/dev/mapper/crypted-nixos";
  resumeKernelParams =
    if enableHibernate && hostCfg.resumeOffset != null
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
    resumeDevice = lib.mkIf enableHibernate (lib.mkDefault resumeDevice);
    kernelParams = lib.mkIf enableHibernate resumeKernelParams;

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
