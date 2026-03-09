{ lib, config, ... }:
let
  hostCfg = config.my.host;
  inherit (hostCfg) enableMullvadVpn;
in
{
  services = {
    # Mullvad VPN
    mullvad-vpn.enable = enableMullvadVpn;

    # Mullvad 依赖 systemd-resolved 管理 DNS 分流（防止 VPN 连接后 DNS 泄漏）
    resolved = lib.mkIf enableMullvadVpn {
      enable = true;
      llmnr = "false"; # 禁用 LLMNR 防止 DNS 投毒
      dnsovertls = "opportunistic";
    };
  };
}
