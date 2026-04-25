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

`wg-nqrvma` is the default autostart profile. The Provider app VPN app / daemon is
not enabled by this catalog; `provider-app-*` entries are plain WireGuard profiles.
The old Provider app app persistence mounts are intentionally kept during migration
so switching from an older generation does not fail on busy mount teardown.

`wg-redacted` is intentionally omitted because no opaque profile config is currently
imported.

Do not enable provider-generated kill switch hooks when exporting configs. The
NixOS `vpn` role owns the kill switch centrally:

- provider configs are decrypted to `/run/wireguard/pool/<profile>/<slot>.conf`
- `/persistent/wireguard/active/<profile>.conf` stores only the selected source
  symlink
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
expecting the kill switch to remain active. LAN is not allowed by default; only
loopback, host-local, DHCP/NDP, WireGuard interface output/forwarding, and
WireGuard-marked endpoint traffic are allowed outside the tunnel. Provider
`Endpoint` values should be IP addresses, not hostnames, because pre-tunnel DNS
is blocked by this policy.

Only one full-tunnel profile should run at a time. Use:

```bash
sudo vpn-status
sudo vpn-select wg-nqrvma slot-a
sudo vpn-switch wg-nqrvma
sudo vpn-stop-all
```

`vpn-select` changes the active candidate symlink under
`/persistent/wireguard/active`. `vpn-switch` stops all declared full-tunnel
profiles before starting the selected one. `vpn-stop-all` stops all declared
profiles but leaves the kill switch active.
