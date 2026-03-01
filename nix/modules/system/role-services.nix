{ lib, pkgs, myvars, mainUser, ... }:
let
  hostRoles = myvars.roles or [ "desktop" ];
  hasRole = role: builtins.elem role hostRoles;

  # 服务开关默认由 roles 驱动，仍允许每台主机通过 enable* 显式覆盖。
  enableSteam = myvars.enableSteam or (hasRole "gaming");
  enableProvider appVpn = myvars.enableProvider appVpn or (hasRole "vpn");
  enableLibvirtd = myvars.enableLibvirtd or (hasRole "virt");
  enableDocker = myvars.enableDocker or (hasRole "container");
  enableFlatpak = myvars.enableFlatpak or (hasRole "desktop");

  # rootful 拥有更高权限，默认改为 rootless；可在主机 vars.nix 里显式覆盖。
  dockerMode = myvars.dockerMode or "rootless";
  useRootlessDocker = dockerMode == "rootless";
  useRootfulDocker = dockerMode == "rootful";
in
{
  assertions = [
    {
      assertion = builtins.elem dockerMode [ "rootless" "rootful" ];
      message = "myvars.dockerMode must be one of: rootless, rootful.";
    }
  ];

  networking.firewall.checkReversePath = if (enableProvider appVpn || enableLibvirtd) then "loose" else "strict";

  programs = {
    # 游戏支持
    steam = lib.mkIf enableSteam {
      enable = true;
      gamescopeSession.enable = true;
      protontricks.enable = true;
      extest.enable = true; # Wayland 下将 X11 输入事件转换为 uinput（Steam Input 控制器支持）
      platformOptimizations.enable = true;
      # 局域网传输与 Remote Play 使用时自动放行防火墙端口
      remotePlay.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;

      # Proton-GE 配置：通过 Steam 的 extraCompatPackages 安装
      # 注意：不能放在 environment.systemPackages（会导致 buildEnv 错误）
      extraCompatPackages = with pkgs; [
        proton-ge-bin
      ];
    };

    gamemode.enable = enableSteam;

    # KVM / libvirt 虚拟化管理
    virt-manager.enable = enableLibvirtd;
  };

  services = {
    # Provider app VPN
    provider-app-vpn.enable = enableProvider appVpn;

    # Provider app 依赖 systemd-resolved 管理 DNS 分流（防止 VPN 连接后 DNS 泄漏）
    resolved.enable = enableProvider appVpn;

    flatpak.enable = enableFlatpak;
  };

  virtualisation = {
    libvirtd = {
      enable = enableLibvirtd;
      qemu.swtpm.enable = true;
    };

    # Docker 容器（rootful/rootless 可切换）
    docker = {
      enable = enableDocker && useRootfulDocker;
      enableOnBoot = false; # 按需 socket activation 启动（减少开机时间）
      autoPrune = {
        enable = true;
        dates = "weekly";
        flags = [ "--all" ]; # 清理所有未使用的镜像（不仅悬空镜像）
      };
    };
    docker.rootless = {
      enable = enableDocker && useRootlessDocker;
      setSocketVariable = true;
    };
  };

  users.users.${mainUser}.extraGroups = lib.mkAfter (
    (lib.optionals enableLibvirtd [
      "libvirtd"
      "kvm"
    ])
    ++ (lib.optionals (enableDocker && useRootfulDocker) [ "docker" ])
  );
}
