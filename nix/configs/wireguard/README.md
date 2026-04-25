# WireGuard VPN Configs

This directory owns the declarative WireGuard VPN catalog used by the NixOS
`vpn` role.

Provider `.conf` files contain `PrivateKey`. Do not commit plaintext `.conf`
files. Import them as encrypted SOPS YAML files under anonymized paths:

```text
secrets/common/wireguard/items/<opaque>.yaml
```

Each encrypted YAML file contains one key:

```yaml
value: |
  [Interface]
  PrivateKey = ...
  Address = ...
  DNS = ...

  [Peer]
  PublicKey = ...
  AllowedIPs = 0.0.0.0/0, ::/0
  Endpoint = ...
```

Stable profiles are declared in `catalog.nix`. The current set is:

- `wg-nqrvma`
- `wg-vdrkye`
- `wg-xafmcp`
- `wg-hzplwt`
- `wg-kqsjdn`

`wg-xafmcp` is the default autostart profile. Profile names, secret file names,
and runtime paths are intentionally opaque: do not encode provider names,
regions, city names, endpoint numbers, or account identifiers in them.

Do not enable provider-generated kill switch hooks when exporting configs. The
NixOS `vpn` role owns the kill switch centrally:

- provider configs are decrypted to `/run/wireguard/pool/<profile>/<slot>.conf`
- `/persistent/wireguard/active/<profile>.conf` stores only the selected source
  symlink
- SOPS secrets are prepared by NixOS activation before normal systemd services;
  the `wg-quick-*` units wait for `network-online.target`, not for a
  `sops-nix.service`
- each `wg-quick-*` unit renders a temporary wrapper config under
  `/run/wireguard/active/<profile>.conf`
- the wrapper injects `FwMark = 51820`
- the `iptables` backend of the NixOS firewall keeps a persistent
  `NIXOS_WG_KILLSWITCH` chain that blocks host outbound non-VPN traffic,
  including after `vpn-stop-all`
- a separate `NIXOS_WG_KILLSWITCH_FWD` chain blocks forwarded non-VPN traffic,
  so VM/container forwarding cannot bypass the VPN

This follows the same `wg-quick` fwmark principle as the upstream kill switch
example, but keeps the blocking firewall rule active outside individual
`wg-quick` service lifetimes. Do not disable or stop the NixOS firewall while
expecting the kill switch to remain active. Host outbound access to private
LAN/link-local ranges is allowed outside the tunnel: RFC1918 IPv4,
`169.254.0.0/16`, IPv6 ULA, and IPv6 link-local. Public IPv4/IPv6 egress still
has to use WireGuard-marked traffic or a WireGuard interface. Provider
`Endpoint` values should be IP addresses, not hostnames, because pre-tunnel DNS
is blocked by this policy.

Only one full-tunnel profile should run at a time. Use:

```bash
sudo vpn-status
sudo vpn-select wg-xafmcp slot-a
sudo vpn-switch wg-xafmcp
sudo vpn-stop-all
```

`vpn-select` changes the active candidate symlink under
`/persistent/wireguard/active`. `vpn-switch` stops loaded `wg-quick-*` services
and all declared full-tunnel profiles before starting the selected one.
`vpn-stop-all` uses the same stop path but leaves the kill switch active.
