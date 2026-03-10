{
  hostName = "zly";
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
  resumeOffset = 10113490;

  cpuVendor = "amd";
  gpuMode = "amd-nvidia-hybrid";
  amdgpuBusId = "PCI:18@0:0:0";
  nvidiaBusId = "PCI:1@0:0:0";
  nvidiaOpen = true;
  dockerMode = "rootless";
  software = {
    virtManager = true;
    virtViewer = true;
    dive = true;
    lazydocker = true;
    dockerCompose = true;
  };
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
    "virt"
    "container"
  ];
}
