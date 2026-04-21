{ pkgs, lib, config, mylib, ... }:
let
  hostCfg = config.my.host;
  roleFlags = mylib.roleFlags hostCfg;
  inherit (roleFlags) enableProvider appVpn;

  provider-appExe = lib.getExe' pkgs.provider-app "provider-app";
  systemctlExe = lib.getExe' pkgs.systemd "systemctl";
  loggerExe = lib.getExe' pkgs.util-linux "logger";
  flockExe = lib.getExe' pkgs.util-linux "flock";
  sleepExe = lib.getExe' pkgs.coreutils "sleep";
  dateExe = lib.getExe' pkgs.coreutils "date";
  catExe = lib.getExe' pkgs.coreutils "cat";
  rmExe = lib.getExe' pkgs.coreutils "rm";
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

  systemd = lib.mkIf enableProvider appVpn {
    services = {
      provider-app-daemon = {
        startLimitBurst = lib.mkForce 6;
        startLimitIntervalSec = lib.mkForce 300;
        serviceConfig.RestartSec = lib.mkForce "5s";
      };

      provider-app-recover = {
        description = "Conservative Provider app VPN recovery";
        after = [ "network-online.target" "provider-app-daemon.service" ];
        wants = [ "network-online.target" "provider-app-daemon.service" ];
        path = [ pkgs.provider-app pkgs.systemd pkgs.util-linux pkgs.coreutils ];
        serviceConfig = {
          Type = "oneshot";
          StateDirectory = "provider-app-recover";
          RuntimeDirectory = "provider-app-recover";
        };
        script = ''
          set -eu

          tag="provider-app-recover"
          state_dir="/var/lib/provider-app-recover"
          run_dir="/run/provider-app-recover"
          trouble_since_file="$state_dir/trouble-since"
          last_action_file="$state_dir/last-action"
          min_trouble_age=600
          action_cooldown=900

          log() {
            ${loggerExe} -t "$tag" "$*"
          }

          now="$(${dateExe} +%s)"

          read_ts() {
            file="$1"
            if [ -s "$file" ]; then
              ${catExe} "$file" 2>/dev/null || printf '0'
            else
              printf '0'
            fi
          }

          is_recent() {
            ts="$1"
            window="$2"
            [ "$ts" -gt 0 ] && [ $((now - ts)) -lt "$window" ]
          }

          exec 9>"$run_dir/lock"
          if ! ${flockExe} -n 9; then
            log "another recovery run is already active, skipping"
            exit 0
          fi

          status="$(${provider-appExe} status 2>&1 || true)"
          case "$status" in
            *Connected*)
              ${rmExe} -f "$trouble_since_file"
              log "status healthy: $status"
              exit 0
              ;;
            *Connecting*)
              trouble_kind="connecting"
              ;;
            *)
              trouble_kind="unhealthy"
              ;;
          esac

          trouble_since="$(read_ts "$trouble_since_file")"
          if [ "$trouble_since" -le 0 ]; then
            printf '%s\n' "$now" > "$trouble_since_file"
            log "observed $trouble_kind status, waiting before recovery: $status"
            exit 0
          fi

          trouble_age=$((now - trouble_since))
          if [ "$trouble_age" -lt "$min_trouble_age" ]; then
            log "status still $trouble_kind for ''${trouble_age}s, below ''${min_trouble_age}s threshold: $status"
            exit 0
          fi

          last_action="$(read_ts "$last_action_file")"
          if is_recent "$last_action" "$action_cooldown"; then
            log "status still $trouble_kind, but recovery is cooling down: $status"
            exit 0
          fi

          printf '%s\n' "$now" > "$last_action_file"
          log "status stuck for ''${trouble_age}s, restarting provider-app-daemon: $status"
          ${systemctlExe} restart provider-app-daemon.service
          ${sleepExe} 10

          post_restart_status="$(${provider-appExe} status 2>&1 || true)"
          case "$post_restart_status" in
            *Connected*|*Connecting*)
              log "daemon restart left provider-app in active state: $post_restart_status"
              ;;
            *)
              log "daemon restart did not restore active state, requesting provider-app connect: $post_restart_status"
              ${provider-appExe} connect 2>&1 | ${loggerExe} -t "$tag" || true
              ;;
          esac

          printf '%s\n' "$now" > "$trouble_since_file"
        '';
      };
    };

    timers.provider-app-recover = {
      description = "Periodic conservative Provider app VPN recovery";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "3min";
        OnUnitActiveSec = "5min";
        RandomizedDelaySec = "60s";
        Persistent = true;
        Unit = "provider-app-recover.service";
      };
    };
  };
}
