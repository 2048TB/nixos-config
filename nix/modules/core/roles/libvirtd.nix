{ lib, config, pkgs, mainUser, mylib, ... }:
let
  hostCfg = config.my.host;
  roleFlags = mylib.roleFlags hostCfg;
  inherit (roleFlags) enableLibvirtd;
  libvirtPackage = config.virtualisation.libvirtd.package;
  defaultNetworkName = "default";
  defaultNetworkXml = ./libvirtd-default-network.xml;
in
{
  programs.virt-manager.enable = enableLibvirtd;

  virtualisation.libvirtd = {
    enable = enableLibvirtd;
    qemu.swtpm.enable = true;
    onBoot = "ignore"; # 不自动恢复 VM，按需 virsh start
  };

  users.users.${mainUser}.extraGroups = lib.mkAfter (
    lib.optionals enableLibvirtd [
      "libvirtd"
      "kvm"
    ]
  );

  systemd.services.libvirt-default-network = lib.mkIf enableLibvirtd {
    description = "Ensure libvirt default network is defined and active";
    wantedBy = [ "multi-user.target" ];
    requires = [ "libvirtd.service" ];
    after = [
      "libvirtd.service"
      "libvirtd-config.service"
    ];
    restartTriggers = [ defaultNetworkXml ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "libvirt-default-network" ''
        set -euo pipefail

        if ! ${libvirtPackage}/bin/virsh net-info ${defaultNetworkName} >/dev/null 2>&1; then
          ${libvirtPackage}/bin/virsh net-define ${defaultNetworkXml}
        fi

        if ! ${libvirtPackage}/bin/virsh net-info ${defaultNetworkName} | ${pkgs.gnugrep}/bin/grep -Eq 'Autostart:\s+yes'; then
          ${libvirtPackage}/bin/virsh net-autostart ${defaultNetworkName}
        fi

        if ! ${libvirtPackage}/bin/virsh net-info ${defaultNetworkName} | ${pkgs.gnugrep}/bin/grep -Eq 'Active:\s+yes'; then
          ${libvirtPackage}/bin/virsh net-start ${defaultNetworkName}
        fi
      '';
    };
  };
}
