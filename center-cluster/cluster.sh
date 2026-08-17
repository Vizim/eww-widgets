#!/bin/bash
# Start / reload / stop the center cluster.
#   ./cluster.sh start | stop | reload | restart | status
set -u

CFG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EWW=$(command -v eww) || { echo "eww not found in PATH" >&2; exit 1; }

WINDOWS=(
  profile
  link_github link_youtube link_reddit link_whatsapp
  media blockclock apps
  power_off power_suspend power_logout power_reboot
  system resources
)

wait_ready() {
  for _ in $(seq 1 40); do
    "$EWW" -c "$CFG" ping >/dev/null 2>&1 && return 0
    sleep 0.25
  done
  echo "eww daemon did not come up" >&2
  return 1
}

start() {
  "$EWW" -c "$CFG" ping >/dev/null 2>&1 || {
    setsid "$EWW" -c "$CFG" daemon >/dev/null 2>&1 < /dev/null &
    wait_ready || exit 1
  }
  # An eww client can wedge holding its pipe open, so cap it and detach the fds.
  timeout 30 "$EWW" -c "$CFG" open-many "${WINDOWS[@]}" >/dev/null 2>&1 < /dev/null
  echo "cluster started"
}

stop() {
  timeout 10 "$EWW" -c "$CFG" close-all >/dev/null 2>&1 < /dev/null || true
  timeout 10 "$EWW" -c "$CFG" kill      >/dev/null 2>&1 < /dev/null || true
  # Also clear the daemon and any client still wedged on the socket. A survivor
  # keeps serving the previous config, so edits appear not to take effect.
  pkill    -f "eww -c $CFG" 2>/dev/null || true
  sleep 0.5
  pkill -9 -f "eww -c $CFG" 2>/dev/null || true
  echo "cluster stopped"
}

case "${1:-start}" in
  start)   start ;;
  stop)    stop ;;
  reload)  timeout 20 "$EWW" -c "$CFG" reload >/dev/null 2>&1 < /dev/null; sleep 0.5; start ;;
  restart) stop; sleep 1; start ;;
  status)  timeout 10 "$EWW" -c "$CFG" active-windows 2>/dev/null < /dev/null || echo "not running" ;;
  *)       echo "usage: ${0##*/} start|stop|reload|restart|status" >&2; exit 2 ;;
esac
