{ config
, lib
, myvars
, ...
}:
let
  cpuVendor = myvars.cpuVendor or "auto";
  hasAmd = cpuVendor != "intel";
  hasIntel = cpuVendor != "amd";
  kvmModules =
    if hasAmd || hasIntel
    then
      (lib.optionals hasAmd [ "kvm-amd" ])
      ++ (lib.optionals hasIntel [ "kvm-intel" ])
    else [ "kvm-amd" "kvm-intel" ];
  kvmExtraModprobeConfig = lib.concatStringsSep "\n" (lib.flatten [
    (lib.optional hasAmd "options kvm_amd nested=1")
    (lib.optional hasIntel "options kvm_intel nested=1")
  ]);
  enableHibernate = myvars.enableHibernate or true;
  resumeDevice =
    if config.fileSystems ? "/swap" && config.fileSystems."/swap" ? device
    then config.fileSystems."/swap".device
    else "/dev/mapper/crypted-nixos";
  resumeKernelParams =
    if enableHibernate && myvars ? resumeOffset && myvars.resumeOffset != null
    then [ "resume_offset=${toString myvars.resumeOffset}" ]
    else [ ];
in
{
  boot = {
    # 引导加载器
    loader = {
      systemd-boot = {
        enable = lib.mkDefault true;
        configurationLimit = lib.mkDefault 10;
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
    extraModprobeConfig = kvmExtraModprobeConfig;
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

    # zram 场景下的内核内存回收参数
    kernel.sysctl = {
      "vm.swappiness" = 180;
      "vm.watermark_boost_factor" = 0;
      "vm.watermark_scale_factor" = 125;
      "vm.page-cluster" = 0;
    };
  };
}
