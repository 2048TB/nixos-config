_:
rec {
  deriveHostCapabilities =
    host:
    let
      kind = host.kind or "workstation";
      formFactor = host.formFactor or "desktop";
      desktopSession = host.desktopSession or false;
      gpuVendors = host.gpuVendors or [ ];
    in
    {
      isWorkstation = kind == "workstation";
      isServer = kind == "server";
      isVm = kind == "vm";
      isDesktop = formFactor == "desktop";
      isLaptop = formFactor == "laptop";
      hasDesktopSession = desktopSession;
      hasAmdGpu = builtins.elem "amd" gpuVendors;
      hasIntelGpu = builtins.elem "intel" gpuVendors;
      hasNvidiaGpu = builtins.elem "nvidia" gpuVendors;
    };
}
