{ config, lib, mylib, pkgs, ... }:
let
  hostCfg = config.my.host;
  roleFlags = mylib.roleFlags hostCfg;
  inherit (roleFlags) enableProvider appVpn enableLibvirtd;

  iptablesExe = "${pkgs.iptables}/bin/iptables";
  ip6tablesExe = "${pkgs.iptables}/bin/ip6tables";
  killSwitchChain = "nixos-provider-app-killswitch";

  mkKillSwitchRules = tableExe: isIPv6: ''
    ${tableExe} -w -N ${killSwitchChain} 2>/dev/null || true
    ${tableExe} -w -F ${killSwitchChain}
    ${tableExe} -w -C OUTPUT -j ${killSwitchChain} 2>/dev/null || \
      ${tableExe} -w -I OUTPUT 1 -j ${killSwitchChain}

    ${tableExe} -w -A ${killSwitchChain} -o lo -j RETURN
    ${tableExe} -w -A ${killSwitchChain} -o wg-provider-app -j RETURN
    ${tableExe} -w -A ${killSwitchChain} -o tun0 -j RETURN

    ${if isIPv6 then ''
      ${tableExe} -w -A ${killSwitchChain} -p ipv6-icmp --icmpv6-type 133 -j RETURN
      ${tableExe} -w -A ${killSwitchChain} -p ipv6-icmp --icmpv6-type 135 -j RETURN
      ${tableExe} -w -A ${killSwitchChain} -p ipv6-icmp --icmpv6-type 136 -j RETURN
      ${tableExe} -w -A ${killSwitchChain} -p udp --sport 546 --dport 547 -j RETURN
    '' else ''
      ${tableExe} -w -A ${killSwitchChain} -p udp --sport 68 --dport 67 -j RETURN
    ''}

    # Provider app relay/API bootstrap escape hatch. The daemon runs as root in the
    # upstream NixOS service; this keeps ordinary user traffic from falling back
    # to the physical interface while still allowing the daemon to rebuild the
    # tunnel. Keep this list intentionally small and auditable.
    ${tableExe} -w -A ${killSwitchChain} -m owner --uid-owner 0 -p udp -m multiport --dports 53,123,51820 -j RETURN
    ${tableExe} -w -A ${killSwitchChain} -m owner --uid-owner 0 -p tcp --dport 443 -j RETURN

    ${tableExe} -w -A ${killSwitchChain} -m limit --limit 6/min --limit-burst 10 -j LOG --log-prefix "provider-app killswitch drop: " --log-level 4
    ${tableExe} -w -A ${killSwitchChain} -j REJECT
  '';

  mkKillSwitchStopRules = tableExe: ''
    while ${tableExe} -w -C OUTPUT -j ${killSwitchChain} 2>/dev/null; do
      ${tableExe} -w -D OUTPUT -j ${killSwitchChain}
    done
    ${tableExe} -w -F ${killSwitchChain} 2>/dev/null || true
    ${tableExe} -w -X ${killSwitchChain} 2>/dev/null || true
  '';
in
{
  networking.firewall = {
    checkReversePath = if (enableProvider appVpn || enableLibvirtd) then "loose" else "strict";

    extraCommands = lib.mkIf enableProvider appVpn ''
      ${mkKillSwitchRules iptablesExe false}
      ${mkKillSwitchRules ip6tablesExe true}
    '';

    extraStopCommands = lib.mkIf enableProvider appVpn ''
      ${mkKillSwitchStopRules iptablesExe}
      ${mkKillSwitchStopRules ip6tablesExe}
    '';
  };
}
