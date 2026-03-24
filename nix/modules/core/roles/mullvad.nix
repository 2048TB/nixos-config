{ pkgs, lib, config, mylib, ... }:
let
  hostCfg = config.my.host;
  roleFlags = mylib.roleFlags hostCfg;
  inherit (roleFlags) enableMullvadVpn;

  mullvadExe = lib.getExe' pkgs.mullvad "mullvad";
  loggerExe = lib.getExe' pkgs.util-linux "logger";
  sleepExe = lib.getExe' pkgs.coreutils "sleep";
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

  # 当底层网络变化（如 OpenWrt Passwall 断开/恢复）时，自动触发 Mullvad 重连。
  # WireGuard 隧道绑定旧 NAT 映射，上游网关重启后 UDP session 失效，需主动重建。
  networking.networkmanager.dispatcherScripts = lib.mkIf enableMullvadVpn [{
    source = pkgs.writeShellScript "mullvad-connect-on-connectivity-change" ''
      interface="$1"
      action="$2"

      case "$action" in
        connectivity-change|up)
          # 等待网络稳定后再触发重连，避免 Passwall 恢复瞬间的瞬态抖动
          ${sleepExe} 2

          status="$(${mullvadExe} status 2>/dev/null || echo "unknown")"
          case "$status" in
            *Connected*|*Connecting*)
              # 已连接或正在连接，不干扰 daemon 自身的重连状态机
              ;;
            *)
              # mullvad reconnect 在 Disconnected 状态下静默无操作（上游 #6220），
              # 必须使用 connect 才能从断连状态恢复。
              ${loggerExe} -t mullvad-dispatcher "network $action on $interface, mullvad status: $status — triggering connect"
              ${mullvadExe} connect 2>/dev/null || true
              ;;
          esac
          ;;
      esac
    '';
    type = "basic";
  }];
}
