{
  hostName = "zky";
  username = "z";
  system = "x86_64-linux";
  formFactor = "laptop";
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
  resumeOffset = 2990172;

  cpuVendor = "intel";
  gpuMode = "nvidia";
  nvidiaOpen = true;
  software = { };
  homeSoftware = {
    cli = true;
    dev = true;
    desktopCore = true;
    browser = true;
    chat = true;
    remote = true;
    media = true;
    archive = true;
  };

  roles = [
    "desktop"
    "vpn"
  ];
}
