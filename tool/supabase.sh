#!/usr/bin/env bash
set -euo pipefail
export SUPABASE_TELEMETRY_DISABLED=1 DO_NOT_TRACK=1
case "${1:-}" in
  start)
    shift
    if ! docker network inspect friend-pager-local >/dev/null 2>&1; then
      docker network create -o com.docker.network.bridge.host_binding_ipv4=127.0.0.1 friend-pager-local >/dev/null
    fi
    test "$(docker network inspect -f '{{index .Options "com.docker.network.bridge.host_binding_ipv4"}}' friend-pager-local)" = 127.0.0.1
    exec supabase start --network-id friend-pager-local "$@"
    ;;
  stop|status) exec supabase "$@" ;;
  reset) exec supabase db reset --local --network-id friend-pager-local ;;
  *) echo 'Use: bash tool/supabase.sh start|stop|status|reset' >&2; exit 1 ;;
esac
