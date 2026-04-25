{ lib, config, mylib, pkgs, ... }:
let
  hostCfg = config.my.host;
  roleFlags = mylib.roleFlags hostCfg;
  inherit (roleFlags) enableVpn;

  wireguardCatalog = import ../../../configs/wireguard/catalog.nix;
  wireguardProfiles = wireguardCatalog.profiles;
  inherit (wireguardCatalog) activeDir defaultProfile;
  renderedDir = "/run/wireguard/active";
  killSwitchChain = "NIXOS_WG_KILLSWITCH";
  killSwitchForwardChain = "NIXOS_WG_KILLSWITCH_FWD";
  killSwitchMark = "51820";
  validProfiles = builtins.attrNames wireguardProfiles;
  validProfilesText = lib.concatStringsSep " " validProfiles;
  activeSourcePath = profileName: "${activeDir}/${profileName}.conf";
  renderedConfigPath = profileName: "${renderedDir}/${profileName}.conf";
  profileAutostarts = lib.filter
    (profileName: wireguardProfiles.${profileName}.autostart or (profileName == defaultProfile))
    validProfiles;

  candidateEntries = lib.flatten (
    lib.mapAttrsToList
      (
        profileName: profile:
          lib.mapAttrsToList
            (
              candidateName: candidate:
                {
                  inherit profileName candidateName;
                  inherit (candidate) runtimePath;
                }
            )
            profile.candidates
      )
      wireguardProfiles
  );

  shellCaseProfiles = lib.concatMapStringsSep "\n      " (profile: "${profile}) ;;") validProfiles;
  shellCaseCandidates = lib.concatMapStringsSep "\n      "
    (
      entry:
      "${entry.profileName}/${entry.candidateName}) target=${lib.escapeShellArg entry.runtimePath} ;;"
    )
    candidateEntries;
  initialActiveLinks = lib.concatMapStringsSep "\n"
    (
      profileName:
      let
        profile = wireguardProfiles.${profileName};
        candidate = profile.candidates.${profile.active};
      in
      ''
        active=${lib.escapeShellArg (activeSourcePath profileName)}
        if [ ! -e "$active" ]; then
          ln -s ${lib.escapeShellArg candidate.runtimePath} "$active"
        fi
      ''
    )
    validProfiles;

  vpnStopAll = pkgs.writeShellScriptBin "vpn-stop-all" ''
    set -eu
    for profile in ${validProfilesText}; do
      ${pkgs.systemd}/bin/systemctl stop "wg-quick-$profile.service" 2>/dev/null || true
    done
  '';

  vpnSwitch = pkgs.writeShellScriptBin "vpn-switch" ''
    set -eu
    target="''${1:-}"
    case "$target" in
      ${shellCaseProfiles}
      *)
        echo "usage: vpn-switch <profile>" >&2
        echo "profiles: ${validProfilesText}" >&2
        exit 2
        ;;
    esac

    ${vpnStopAll}/bin/vpn-stop-all
    ${pkgs.systemd}/bin/systemctl start "wg-quick-$target.service"
    ${pkgs.systemd}/bin/systemctl --no-pager --full status "wg-quick-$target.service" || true
    ${pkgs.wireguard-tools}/bin/wg show || true
    ${pkgs.iproute2}/bin/ip route show default || true
  '';

  vpnSelect = pkgs.writeShellScriptBin "vpn-select" ''
    set -eu
    profile="''${1:-}"
    candidate="''${2:-}"
    if [ -z "$profile" ] || [ -z "$candidate" ]; then
      echo "usage: vpn-select <profile> <candidate>" >&2
      echo "example: vpn-select wg-nqrvma slot-a" >&2
      exit 2
    fi

    target=""
    case "$profile/$candidate" in
      ${shellCaseCandidates}
      *)
        echo "invalid profile/candidate: $profile/$candidate" >&2
        echo "profiles: ${validProfilesText}" >&2
        exit 2
        ;;
    esac

    if [ ! -r "$target" ]; then
      echo "missing decrypted config: $target" >&2
      echo "hint: run nixos-rebuild switch and check sops-nix before selecting it" >&2
      exit 1
    fi

    active="${activeDir}/$profile.conf"
    ${pkgs.coreutils}/bin/install -d -m 0700 ${lib.escapeShellArg activeDir}
    ${pkgs.coreutils}/bin/ln -sfn "$target" "$active"
    echo "$profile -> $target"
  '';

  vpnStatus = pkgs.writeShellScriptBin "vpn-status" ''
    set -eu
    for profile in ${validProfilesText}; do
      state="$(${pkgs.systemd}/bin/systemctl is-active "wg-quick-$profile.service" 2>/dev/null || true)"
      printf '%s %s\n' "$profile" "$state"
    done
    ${pkgs.wireguard-tools}/bin/wg show || true
    ${pkgs.iproute2}/bin/ip route show default || true
  '';

  renderActiveConfig = profileName: ''
    set -eu
    source=${lib.escapeShellArg (activeSourcePath profileName)}
    target=${lib.escapeShellArg (renderedConfigPath profileName)}
    tmp="$target.tmp"

    if [ ! -r "$source" ]; then
      echo "missing active WireGuard config source: $source" >&2
      echo "hint: run vpn-select ${profileName} <candidate> after sops-nix has decrypted secrets" >&2
      exit 1
    fi

    ${pkgs.coreutils}/bin/install -d -m 0700 ${lib.escapeShellArg renderedDir}
    ${pkgs.gawk}/bin/awk '
      /^[[:space:]]*FwMark[[:space:]]*=/ { next }
      /^[[:space:]]*\[Peer\][[:space:]]*$/ && !inserted {
        print "FwMark = ${killSwitchMark}"
        inserted = 1
      }
      { print }
      END {
        if (!inserted) {
          print "FwMark = ${killSwitchMark}"
        }
      }
    ' "$source" > "$tmp"
    ${pkgs.coreutils}/bin/chmod 0400 "$tmp"
    ${pkgs.coreutils}/bin/mv -f "$tmp" "$target"
  '';

  firewallPackage = config.networking.firewall.package;
  iptables = "${firewallPackage}/bin/iptables -w";
  ip6tables = "${firewallPackage}/bin/ip6tables -w";
  allowProfileOutputs = lib.concatMapStringsSep "\n"
    (profileName: ''
      ${iptables} -A ${killSwitchChain} -o ${lib.escapeShellArg profileName} -j RETURN
    '')
    validProfiles;
  allowProfileOutputs6 = lib.concatMapStringsSep "\n"
    (profileName: ''
      ${ip6tables} -A ${killSwitchChain} -o ${lib.escapeShellArg profileName} -j RETURN
    '')
    validProfiles;
  allowProfileForward4 = lib.concatMapStringsSep "\n"
    (profileName: ''
      ${iptables} -A ${killSwitchForwardChain} -o ${lib.escapeShellArg profileName} -j RETURN
      ${iptables} -A ${killSwitchForwardChain} -i ${lib.escapeShellArg profileName} -j RETURN
    '')
    validProfiles;
  allowProfileForward6 = lib.concatMapStringsSep "\n"
    (profileName: ''
      ${ip6tables} -A ${killSwitchForwardChain} -o ${lib.escapeShellArg profileName} -j RETURN
      ${ip6tables} -A ${killSwitchForwardChain} -i ${lib.escapeShellArg profileName} -j RETURN
    '')
    validProfiles;
  killSwitchSetup = ''
    ${iptables} -N ${killSwitchChain} 2>/dev/null || ${iptables} -F ${killSwitchChain}
    ${iptables} -C OUTPUT -j ${killSwitchChain} 2>/dev/null || ${iptables} -I OUTPUT 1 -j ${killSwitchChain}
    ${iptables} -A ${killSwitchChain} -o lo -j RETURN
    ${allowProfileOutputs}
    ${iptables} -A ${killSwitchChain} -m mark --mark ${killSwitchMark} -j RETURN
    ${iptables} -A ${killSwitchChain} -m addrtype --dst-type LOCAL -j RETURN
    ${iptables} -A ${killSwitchChain} -m addrtype --dst-type BROADCAST -j RETURN
    ${iptables} -A ${killSwitchChain} -p udp --sport 68 --dport 67 -j RETURN
    ${iptables} -A ${killSwitchChain} -j REJECT

    ${iptables} -N ${killSwitchForwardChain} 2>/dev/null || ${iptables} -F ${killSwitchForwardChain}
    ${iptables} -C FORWARD -j ${killSwitchForwardChain} 2>/dev/null || ${iptables} -I FORWARD 1 -j ${killSwitchForwardChain}
    ${allowProfileForward4}
    ${iptables} -A ${killSwitchForwardChain} -j REJECT

    ${ip6tables} -N ${killSwitchChain} 2>/dev/null || ${ip6tables} -F ${killSwitchChain}
    ${ip6tables} -C OUTPUT -j ${killSwitchChain} 2>/dev/null || ${ip6tables} -I OUTPUT 1 -j ${killSwitchChain}
    ${ip6tables} -A ${killSwitchChain} -o lo -j RETURN
    ${allowProfileOutputs6}
    ${ip6tables} -A ${killSwitchChain} -m mark --mark ${killSwitchMark} -j RETURN
    ${ip6tables} -A ${killSwitchChain} -m addrtype --dst-type LOCAL -j RETURN
    ${ip6tables} -A ${killSwitchChain} -p ipv6-icmp --icmpv6-type router-solicitation -j RETURN
    ${ip6tables} -A ${killSwitchChain} -p ipv6-icmp --icmpv6-type router-advertisement -j RETURN
    ${ip6tables} -A ${killSwitchChain} -p ipv6-icmp --icmpv6-type neighbour-solicitation -j RETURN
    ${ip6tables} -A ${killSwitchChain} -p ipv6-icmp --icmpv6-type neighbour-advertisement -j RETURN
    ${ip6tables} -A ${killSwitchChain} -p udp --sport 546 --dport 547 -j RETURN
    ${ip6tables} -A ${killSwitchChain} -j REJECT

    ${ip6tables} -N ${killSwitchForwardChain} 2>/dev/null || ${ip6tables} -F ${killSwitchForwardChain}
    ${ip6tables} -C FORWARD -j ${killSwitchForwardChain} 2>/dev/null || ${ip6tables} -I FORWARD 1 -j ${killSwitchForwardChain}
    ${allowProfileForward6}
    ${ip6tables} -A ${killSwitchForwardChain} -j REJECT
  '';
  killSwitchStop = ''
    ${iptables} -D OUTPUT -j ${killSwitchChain} 2>/dev/null || true
    ${iptables} -F ${killSwitchChain} 2>/dev/null || true
    ${iptables} -X ${killSwitchChain} 2>/dev/null || true
    ${iptables} -D FORWARD -j ${killSwitchForwardChain} 2>/dev/null || true
    ${iptables} -F ${killSwitchForwardChain} 2>/dev/null || true
    ${iptables} -X ${killSwitchForwardChain} 2>/dev/null || true

    ${ip6tables} -D OUTPUT -j ${killSwitchChain} 2>/dev/null || true
    ${ip6tables} -F ${killSwitchChain} 2>/dev/null || true
    ${ip6tables} -X ${killSwitchChain} 2>/dev/null || true
    ${ip6tables} -D FORWARD -j ${killSwitchForwardChain} 2>/dev/null || true
    ${ip6tables} -F ${killSwitchForwardChain} 2>/dev/null || true
    ${ip6tables} -X ${killSwitchForwardChain} 2>/dev/null || true
  '';
in
{
  assertions = lib.mkIf enableVpn [
    {
      assertion = builtins.hasAttr defaultProfile wireguardProfiles;
      message = "WireGuard VPN defaultProfile '${defaultProfile}' is not declared in nix/configs/wireguard/catalog.nix.";
    }
    {
      assertion = builtins.length profileAutostarts == 1;
      message = "WireGuard VPN must autostart exactly one full-tunnel profile; current autostart profiles: ${lib.concatStringsSep " " profileAutostarts}.";
    }
    {
      assertion = builtins.elem defaultProfile profileAutostarts;
      message = "WireGuard VPN defaultProfile '${defaultProfile}' must be the autostart profile.";
    }
    {
      assertion = config.networking.firewall.enable;
      message = "WireGuard VPN kill switch requires networking.firewall.enable = true.";
    }
    {
      assertion = config.networking.firewall.backend == "iptables";
      message = "WireGuard VPN kill switch currently uses iptables firewall hooks; keep networking.firewall.backend = \"iptables\" or port the kill switch to nftables.";
    }
  ];

  networking.wg-quick.interfaces = lib.mkIf enableVpn (
    lib.mapAttrs
      (
        profileName: profile:
          {
            autostart = profile.autostart or (profileName == defaultProfile);
            configFile = renderedConfigPath profileName;
          }
      )
      wireguardProfiles
  );

  services.resolved = lib.mkIf enableVpn {
    enable = true;
    llmnr = "false";
    dnsovertls = "opportunistic";
  };

  systemd = lib.mkIf enableVpn {
    tmpfiles.rules = [
      "d /run/wireguard 0700 root root -"
      "d ${renderedDir} 0700 root root -"
      "d /persistent/wireguard 0700 root root -"
      "d ${activeDir} 0700 root root -"
    ];

    services = lib.mapAttrs'
      (
        profileName: _:
          lib.nameValuePair "wg-quick-${profileName}" {
            after = [
              "sops-nix.service"
              "network-online.target"
            ];
            requires = [ "sops-nix.service" ];
            wants = [ "network-online.target" ];
            preStart = renderActiveConfig profileName;
          }
      )
      wireguardProfiles;
  };

  system.activationScripts.wireguardVpnActiveLinks = lib.mkIf enableVpn {
    text = ''
      ${pkgs.coreutils}/bin/install -d -m 0700 ${lib.escapeShellArg activeDir}
      ${initialActiveLinks}
    '';
    deps = [ "specialfs" ];
  };

  networking.firewall = lib.mkIf enableVpn {
    extraCommands = killSwitchSetup;
    extraStopCommands = killSwitchStop;
  };

  environment.systemPackages = lib.mkIf enableVpn [
    pkgs.wireguard-tools
    vpnStopAll
    vpnSwitch
    vpnSelect
    vpnStatus
  ];
}
