_:
rec {
  deriveHostCapabilities =
    host:
    let
      kind = host.kind or "workstation";
      formFactor = host.formFactor or "desktop";
      desktopSession = host.desktopSession or false;
      desktopProfile = host.desktopProfile or "none";
      gpuVendors = host.gpuVendors or [ ];
      tags = host.tags or [ ];
      displays = host.displays or [ ];
      primaryDisplays = builtins.filter (display: display.primary or false) displays;
      resolvedPrimaryDisplay =
        if primaryDisplays != [ ] then builtins.head primaryDisplays
        else if displays != [ ] then builtins.head displays
        else null;
      displayScales = map
        (
          display:
          let
            scale = display.scale or null;
          in
          if scale == null then 1.0 else scale
        )
        displays;
    in
    {
      isWorkstation = kind == "workstation";
      isServer = kind == "server";
      isVm = kind == "vm";
      isDesktop = formFactor == "desktop";
      isLaptop = formFactor == "laptop";
      hasDesktopSession = desktopSession;
      usesRiver = desktopProfile == "river";
      hasMultipleDisplays = builtins.length displays > 1;
      hasDisplayTopology = displays != [ ];
      hasHiDpiDisplay = builtins.any (scale: scale > 1.0) displayScales;
      primaryDisplayName = if resolvedPrimaryDisplay == null then null else (resolvedPrimaryDisplay.name or null);
      hasFingerprintReader = builtins.elem "fingerprint-reader" tags;
      hasAmdGpu = builtins.elem "amd" gpuVendors;
      hasIntelGpu = builtins.elem "intel" gpuVendors;
      hasNvidiaGpu = builtins.elem "nvidia" gpuVendors;
    };
}
