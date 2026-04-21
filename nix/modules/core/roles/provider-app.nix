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
  headExe = lib.getExe' pkgs.coreutils "head";
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

          classify_status_line() {
            case "$1" in
              Connected|Connected\ *)
                printf '%s\n' healthy
                ;;
              Connecting|Connecting\ *)
                printf '%s\n' connecting
                ;;
              Disconnected|Disconnected\ *|"")
                printf '%s\n' unhealthy
                ;;
              *)
                printf '%s\n' unhealthy
                ;;
            esac
          }

          exec 9>"$run_dir/lock"
          if ! ${flockExe} -n 9; then
            log "another recovery run is already active, skipping"
            exit 0
          fi

          status="$(${provider-appExe} status 2>&1 || true)"
          status_line="$(printf '%s\n' "$status" | ${headExe} -n 1)"
          status_class="$(classify_status_line "$status_line")"
          case "$status_class" in
            healthy)
              ${rmExe} -f "$trouble_since_file"
              log "status healthy, class=$status_class, line: $status_line"
              exit 0
              ;;
            connecting)
              trouble_kind="connecting"
              ;;
            *)
              trouble_kind="unhealthy"
              ;;
          esac

          trouble_since="$(read_ts "$trouble_since_file")"
          if [ "$trouble_since" -le 0 ]; then
            printf '%s\n' "$now" > "$trouble_since_file"
            log "observed $trouble_kind status, class=$status_class, line: $status_line; waiting before recovery"
            exit 0
          fi

          trouble_age=$((now - trouble_since))
          if [ "$trouble_age" -lt "$min_trouble_age" ]; then
            log "status still $trouble_kind for ''${trouble_age}s, below ''${min_trouble_age}s threshold, class=$status_class, line: $status_line"
            exit 0
          fi

          last_action="$(read_ts "$last_action_file")"
          if is_recent "$last_action" "$action_cooldown"; then
            log "status still $trouble_kind, but recovery is cooling down, class=$status_class, line: $status_line"
            exit 0
          fi

          printf '%s\n' "$now" > "$last_action_file"
          log "status stuck for ''${trouble_age}s, restarting provider-app-daemon, class=$status_class, line: $status_line"
          ${systemctlExe} restart provider-app-daemon.service
          ${sleepExe} 10

          post_restart_status="$(${provider-appExe} status 2>&1 || true)"
          post_restart_status_line="$(printf '%s\n' "$post_restart_status" | ${headExe} -n 1)"
          post_restart_status_class="$(classify_status_line "$post_restart_status_line")"
          case "$post_restart_status_class" in
            healthy)
              log "daemon restart restored healthy status, class=$post_restart_status_class, line: $post_restart_status_line"
              ;;
            connecting)
              log "daemon restart left provider-app connecting, class=$post_restart_status_class, line: $post_restart_status_line"
              ;;
            *)
              log "daemon restart did not restore active state, class=$post_restart_status_class, line: $post_restart_status_line; requesting provider-app connect"
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
