{
  hostName = "zzly";
  username = "z";
  system = "x86_64-linux";
  formFactor = "desktop";
  languageTools = [
    "go"
    "node"
    "rust"
    "python"
  ];

  timezone = "Asia/Shanghai";
  systemStateVersion = "25.11";
  homeStateVersion = "25.11";

  diskDevice = "/dev/nvme0n1";
  swapSizeGb = 32;
  resumeOffset = 1513128;

  cpuVendor = "amd";
  gpuMode = "amd";
  software = { };
  homeSoftware = {
    cli = true;
    dev = true;
    desktopCore = true;
    browser = true;
    chat = false;
    remote = true;
    media = false;
    archive = false;
  };

  roles = [
    "desktop"
    "vpn"
  ];
}
