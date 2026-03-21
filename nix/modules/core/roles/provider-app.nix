{ pkgs, lib, config, mylib, ... }:
let
  hostCfg = config.my.host;
  roleFlags = mylib.roleFlags hostCfg;
  inherit (roleFlags) enableProvider appVpn;

  provider-appBin = "${pkgs.provider-app}/bin/provider-app";
  loggerBin = "${pkgs.util-linux}/bin/logger";
  sleepBin = "${lib.getExe' pkgs.coreutils "sleep"}";
in
{
  services = {
    # Provider app VPN
    provider-app-vpn.enable = enableProvider appVpn;

    # Provider app 依赖 systemd-resolved 管理 DNS 分流（防止 VPN 连接后 DNS 泄漏）
    resolved = lib.mkIf enableProvider appVpn {
      enable = true;
      llmnr = "false"; # 禁用 LLMNR 防止 DNS 投毒
      dnsovertls = "opportunistic";
    };
  };

  # 当底层网络变化（如 OpenWrt Passwall 断开/恢复）时，自动触发 Provider app 重连。
  # WireGuard 隧道绑定旧 NAT 映射，上游网关重启后 UDP session 失效，需主动重建。
  networking.networkmanager.dispatcherScripts = lib.mkIf enableProvider appVpn [{
    source = pkgs.writeShellScript "provider-app-reconnect-on-connectivity-change" ''
      interface="$1"
      action="$2"

      case "$action" in
        connectivity-change|up)
          # 等待网络稳定后再触发重连，避免 Passwall 恢复瞬间的瞬态抖动
          ${sleepBin} 2

          status="$(${provider-appBin} status 2>/dev/null || echo "unknown")"
          case "$status" in
            *Connected*)
              # 已连接，无需操作
              ;;
            *)
              ${loggerBin} -t provider-app-dispatcher "network $action on $interface, provider-app status: $status — triggering reconnect"
              ${provider-appBin} reconnect 2>/dev/null || true
              ;;
          esac
          ;;
      esac
    '';
    type = "basic";
  }];
}
