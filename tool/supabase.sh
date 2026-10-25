#!/usr/bin/env bash
set -euo pipefail
export SUPABASE_TELEMETRY_DISABLED=1 DO_NOT_TRACK=1
case "${1:-}" in
  start)
    shift
    if ! docker network inspect friend-pager-local >/dev/null 2>&1; then
      docker network create --internal friend-pager-local >/dev/null
    fi
    test "$(docker network inspect -f '{{.Internal}}' friend-pager-local)" = true
    exec supabase start --network-id friend-pager-local "$@"
    ;;
  stop|status) exec supabase "$@" ;;
  reset) exec supabase db reset --local ;;
  *) echo 'Use: bash tool/supabase.sh start|stop|status|reset' >&2; exit 1 ;;
esac
